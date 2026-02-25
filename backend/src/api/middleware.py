from __future__ import annotations

import time
import uuid
from typing import Callable

from fastapi import Request, Response
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.middleware.base import BaseHTTPMiddleware

from src.core.config import get_settings
from src.core.logging import bind_context, clear_context, get_logger

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

        bind_context(correlation_id=correlation_id)

        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id

        clear_context()

        return response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log requests and responses with beautiful formatting."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()

        # Extract path without query params for cleaner logs
        path = request.url.path
        if request.url.query:
            path = f"{path}?{request.url.query[:100]}"  # Truncate long query strings

        bind_context(
            method=request.method,
            path=path,
            client_ip=request.client.host if request.client else None,
        )

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


class MetricsMiddleware(BaseHTTPMiddleware):
    """Middleware to collect request metrics."""

    def __init__(self, app, metrics_collector=None):
        super().__init__(app)
        self.metrics_collector = metrics_collector
        self.request_count = 0
        self.error_count = 0
        self.total_latency = 0.0

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()

        try:
            response = await call_next(request)
            self.request_count += 1

            if response.status_code >= 400:
                self.error_count += 1

        except Exception:
            self.error_count += 1
            raise
        finally:
            latency = (time.perf_counter() - start_time) * 1000
            self.total_latency += latency

        return response

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


def setup_middleware(app):
    """Setup all application middleware."""
    app.add_middleware(CorrelationIdMiddleware)
    app.add_middleware(RequestLoggingMiddleware)
    app.state.limiter = limiter
