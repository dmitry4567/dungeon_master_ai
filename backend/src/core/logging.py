from __future__ import annotations

import logging
import sys
from typing import Any

import structlog
from structlog.dev import ConsoleRenderer
from structlog.types import Processor

from src.core.config import get_settings

settings = get_settings()


class CustomConsoleRenderer(ConsoleRenderer):
    """Custom console renderer with improved formatting and colors."""

    # Color palette for log levels
    level_styles = {
        "debug": {"fg": "blue"},
        "info": {"fg": "green"},
        "warning": {"fg": "yellow"},
        "error": {"fg": "red"},
        "critical": {"fg": "red", "bold": True},
        "exception": {"fg": "red", "bold": True},
    }

    # Color palette for key-value pairs
    key_styles = {
        "correlation_id": {"fg": "cyan"},
        "duration_ms": {"fg": "magenta"},
        "status_code": {"fg": "magenta"},
        "method": {"fg": "white", "bold": True},
        "path": {"fg": "white"},
        "client_ip": {"fg": "white"},
        "logger": {"fg": "white", "dim": True},
        "timestamp": {"fg": "white", "dim": True},
    }

    def __init__(self) -> None:
        super().__init__(
            colors=True,
            force_colors=True,
            level_styles=self.level_styles,
            key_styles=self.key_styles,
            timestamp_key="timestamp",
            repr_native_str=False,
        )

    def __call__(
        self, logger: logging.Logger, name: str, event_dict: dict[str, Any]
    ) -> str:
        # Add level alias for exception logs
        if "exc_info" in event_dict or "exception" in event_dict:
            event_dict["level"] = "exception"

        return super().__call__(logger, name, event_dict)


def _add_custom_timestamp(
    logger: logging.Logger, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    """Add timestamp in human-readable format with timezone."""
    from datetime import datetime, timezone

    event_dict["timestamp"] = datetime.now(timezone.utc).strftime(
        "%Y-%m-%d %H:%M:%S.%f"
    )[:-3] + " UTC"
    return event_dict


def _format_duration(
    logger: logging.Logger, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    """Format duration in milliseconds with proper unit."""
    if "duration_ms" in event_dict:
        duration = event_dict["duration_ms"]
        if isinstance(duration, (int, float)):
            event_dict["duration_ms"] = f"{duration:.2f}ms"
    return event_dict


def setup_logging() -> None:
    """Setup structured logging with beautiful console output for development."""
    log_level = getattr(logging, settings.log_level.upper(), logging.INFO)

    # Choose processors based on format setting
    if settings.log_format == "json":
        processors: list[Processor] = [
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer(),
        ]
    else:
        # Development mode with beautiful console output
        processors = [
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.PositionalArgumentsFormatter(),
            _add_custom_timestamp,
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            _format_duration,
            CustomConsoleRenderer(),
        ]

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    # Configure standard logging to work with structlog
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=log_level,
    )

    # Suppress default uvicorn logging (we'll handle it ourselves)
    for logger_name in ["uvicorn", "uvicorn.error", "uvicorn.access"]:
        uvicorn_logger = logging.getLogger(logger_name)
        uvicorn_logger.handlers = []
        uvicorn_logger.propagate = False


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Get a structured logger instance."""
    return structlog.get_logger(name)


def bind_context(**kwargs: Any) -> None:
    """Bind context variables to the current logger context."""
    structlog.contextvars.bind_contextvars(**kwargs)


def clear_context() -> None:
    """Clear all context variables."""
    structlog.contextvars.clear_contextvars()


def unbind_context(*keys: str) -> None:
    """Unbind specific context variables."""
    structlog.contextvars.unbind_contextvars(*keys)
