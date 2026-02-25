from __future__ import annotations

import time
import uuid
from typing import Callable

from fastapi import Request, Response
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.middleware.base import BaseHTTPMiddleware

from src.core.config import get_settings
from src.core.logging import get_logger

settings = get_settings()
logger = get_logger(__name__)

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=settings.redis_url,
    default_limits=[f"{settings.rate_limit_requests}/{settings.rate_limit_period}seconds"],
)


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """Middleware to add correlation ID to requests."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        correlation_id = request.headers.get("X-Correlation-ID") or str(uuid.uuid4())
        request.state.correlation_id = correlation_id

        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id

        return response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log requests and responses with beautiful formatting."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()

        # Extract path without query params for cleaner logs
        path = request.url.path
        if request.url.query:
            path = f"{path}?{request.url.query[:100]}"  # Truncate long query strings

        logger.info("Request started: method=%s, path=%s", request.method, path)

        try:
            response = await call_next(request)
        except Exception as exc:
            logger.exception("Request failed: %s", str(exc))
            raise

        process_time = (time.perf_counter() - start_time) * 1000

        # Log with appropriate level based on status code
        if response.status_code >= 500:
            log_method = logger.error
        elif response.status_code >= 400:
            log_method = logger.warning
        else:
            log_method = logger.info

        log_method(
            "Request completed: status_code=%s, duration_ms=%s",
            response.status_code,
            round(process_time, 2),
        )

        response.headers["X-Process-Time"] = str(round(process_time, 2))

        return response


class MetricsCollector:
    """Thread-safe in-memory metrics collector."""

    def __init__(self) -> None:
        self.request_count: int = 0
        self.error_count: int = 0
        self.total_latency: float = 0.0
        # Per-endpoint metrics: {path: {count, errors, total_latency}}
        self.endpoint_metrics: dict[str, dict[str, float]] = {}
        # Latency histogram buckets (ms)
        self._latency_buckets = [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
        self.latency_histogram: dict[str, int] = {str(b): 0 for b in self._latency_buckets}
        self.latency_histogram["inf"] = 0

    def record(self, path: str, status_code: int, latency_ms: float) -> None:
        """Record a single request metric."""
        self.request_count += 1
        self.total_latency += latency_ms

        is_error = status_code >= 400
        if is_error:
            self.error_count += 1

        # Per-endpoint tracking
        if path not in self.endpoint_metrics:
            self.endpoint_metrics[path] = {"count": 0, "errors": 0, "total_latency": 0.0}
        ep = self.endpoint_metrics[path]
        ep["count"] += 1
        ep["total_latency"] += latency_ms
        if is_error:
            ep["errors"] += 1

        # Update histogram
        recorded = False
        for bucket in self._latency_buckets:
            if latency_ms <= bucket:
                self.latency_histogram[str(bucket)] += 1
                recorded = True
                break
        if not recorded:
            self.latency_histogram["inf"] += 1

    @property
    def average_latency(self) -> float:
        if self.request_count == 0:
            return 0.0
        return self.total_latency / self.request_count

    @property
    def error_rate(self) -> float:
        if self.request_count == 0:
            return 0.0
        return self.error_count / self.request_count

    def to_prometheus(self) -> str:
        """Render metrics in Prometheus text format."""
        lines = []

        lines.append("# HELP http_requests_total Total number of HTTP requests")
        lines.append("# TYPE http_requests_total counter")
        lines.append(f"http_requests_total {self.request_count}")

        lines.append("# HELP http_errors_total Total number of HTTP errors (4xx+5xx)")
        lines.append("# TYPE http_errors_total counter")
        lines.append(f"http_errors_total {self.error_count}")

        lines.append("# HELP http_request_duration_ms_avg Average request latency in ms")
        lines.append("# TYPE http_request_duration_ms_avg gauge")
        lines.append(f"http_request_duration_ms_avg {self.average_latency:.2f}")

        lines.append("# HELP http_error_rate Fraction of requests that are errors")
        lines.append("# TYPE http_error_rate gauge")
        lines.append(f"http_error_rate {self.error_rate:.4f}")

        # Latency histogram
        lines.append("# HELP http_request_duration_ms Latency histogram in ms")
        lines.append("# TYPE http_request_duration_ms histogram")
        cumulative = 0
        for bucket_str, count in self.latency_histogram.items():
            cumulative += count
            le = "+Inf" if bucket_str == "inf" else bucket_str
            lines.append(f'http_request_duration_ms_bucket{{le="{le}"}} {cumulative}')
        lines.append(f"http_request_duration_ms_count {self.request_count}")
        lines.append(f"http_request_duration_ms_sum {self.total_latency:.2f}")

        # Per-endpoint metrics
        lines.append("# HELP http_endpoint_requests_total Requests per endpoint")
        lines.append("# TYPE http_endpoint_requests_total counter")
        for path, ep in self.endpoint_metrics.items():
            safe_path = path.replace('"', '\\"')
            lines.append(f'http_endpoint_requests_total{{path="{safe_path}"}} {ep["count"]}')

        return "\n".join(lines) + "\n"

    def to_dict(self) -> dict:
        """Return metrics as a dictionary."""
        return {
            "requests_total": self.request_count,
            "errors_total": self.error_count,
            "error_rate": round(self.error_rate, 4),
            "average_latency_ms": round(self.average_latency, 2),
            "latency_histogram_ms": self.latency_histogram,
            "endpoints": {
                path: {
                    "count": int(ep["count"]),
                    "errors": int(ep["errors"]),
                    "avg_latency_ms": round(ep["total_latency"] / ep["count"], 2)
                    if ep["count"] > 0
                    else 0.0,
                }
                for path, ep in self.endpoint_metrics.items()
            },
        }


# Global metrics collector singleton
metrics_collector = MetricsCollector()


class MetricsMiddleware(BaseHTTPMiddleware):
    """Middleware to collect request latency and error rate metrics."""

    def __init__(self, app, collector: MetricsCollector | None = None):
        super().__init__(app)
        self.collector = collector or metrics_collector

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Skip metrics endpoint itself to avoid recursion
        if request.url.path == "/metrics":
            return await call_next(request)

        start_time = time.perf_counter()
        path = request.url.path
        status_code = 500

        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        except Exception:
            raise
        finally:
            latency_ms = (time.perf_counter() - start_time) * 1000
            self.collector.record(path, status_code, latency_ms)

    @property
    def average_latency(self) -> float:
        return self.collector.average_latency

    @property
    def error_rate(self) -> float:
        return self.collector.error_rate


def setup_middleware(app):
    """Setup all application middleware."""
    app.add_middleware(MetricsMiddleware, collector=metrics_collector)
    app.add_middleware(CorrelationIdMiddleware)
    app.add_middleware(RequestLoggingMiddleware)
    app.state.limiter = limiter
