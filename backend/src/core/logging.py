"""
Beautiful colored logging configuration for the application.
Provides console output with syntax highlighting and optional JSON formatting.
"""

from __future__ import annotations

import logging
import sys
from datetime import datetime
from typing import Any, Literal

from rich.console import Console
from rich.logging import RichHandler
from rich.theme import Theme

# Custom theme for logging
logging_theme = Theme(
    {
        "info": "cyan",
        "warning": "yellow",
        "error": "red",
        "critical": "bold red",
        "debug": "green",
        "success": "bold green",
    }
)

console = Console(theme=logging_theme)


class ColoredFormatter(logging.Formatter):
    """
    Custom formatter with colors for different log levels.
    Uses ANSI escape codes for terminal coloring.
    """

    # ANSI color codes
    COLORS = {
        "DEBUG": "\033[36m",  # Cyan
        "INFO": "\033[32m",  # Green
        "WARNING": "\033[33m",  # Yellow
        "ERROR": "\033[31m",  # Red
        "CRITICAL": "\033[35m",  # Magenta
        "RESET": "\033[0m",  # Reset
    }

    # Emoji for each log level
    EMOJIS = {
        "DEBUG": "🐛",
        "INFO": "ℹ️",
        "WARNING": "⚠️",
        "ERROR": "❌",
        "CRITICAL": "🔥",
    }

    def __init__(
        self,
        fmt: str | None = None,
        datefmt: str | None = None,
        use_colors: bool = True,
    ) -> None:
        super().__init__(
            fmt=fmt or "%(asctime)s %(level_emoji)s %(name)s | %(message)s",
            datefmt=datefmt or "%H:%M:%S",
        )
        self.use_colors = use_colors

    def format(self, record: logging.LogRecord) -> str:
        # Save original levelname
        original_levelname = record.levelname

        # Add emoji
        emoji = self.EMOJIS.get(record.levelname, "")
        record.level_emoji = emoji  # type: ignore

        # Apply colors if enabled and stream supports it
        if self.use_colors and sys.stdout.isatty():
            color = self.COLORS.get(record.levelname, self.COLORS["RESET"])
            record.levelname = f"{color}{record.levelname}{self.COLORS['RESET']}"
            record.name = f"\033[36m{record.name}\033[0m"  # Cyan for logger name
            record.msg = f"\033[1m{record.msg}\033[0m"  # Bold for message

        # Format the record
        result = super().format(record)

        # Restore original levelname
        record.levelname = original_levelname

        return result


class DungeonMasterFormatter(ColoredFormatter):
    """
    Themed formatter with Dungeon Master aesthetic.
    """

    # Dungeon Master specific colors
    COLORS = {
        "DEBUG": "\033[38;5;27m",  # Deep blue
        "INFO": "\033[38;5;34m",  # Forest green
        "WARNING": "\033[38;5;214m",  # Orange
        "ERROR": "\033[38;5;196m",  # Bright red
        "CRITICAL": "\033[38;5;129m",  # Purple
        "RESET": "\033[0m",
    }

    # Fantasy-themed emojis
    EMOJIS = {
        "DEBUG": "🔮",  # Crystal ball
        "INFO": "📜",  # Scroll
        "WARNING": "⚔️",  # Swords
        "ERROR": "🐉",  # Dragon
        "CRITICAL": "💀",  # Skull
    }


def setup_logging(
    level: str = "INFO",
    log_format: Literal["console", "json", "dungeon"] = "console",
    logger_name: str | None = None,
) -> logging.Logger:
    """
    Configure logging with beautiful colored output.

    Args:
        level: Minimum log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_format: Output format - 'console' (colored), 'json', or 'dungeon' (themed)
        logger_name: Name of the logger. If None, configures root logger.

    Returns:
        Configured logger instance
    """
    # Get logger
    if logger_name:
        logger = logging.getLogger(logger_name)
    else:
        logger = logging.getLogger()

    logger.setLevel(getattr(logging, level.upper()))

    # Clear existing handlers
    logger.handlers.clear()

    # Select formatter
    if log_format == "json":
        formatter = logging.Formatter(
            '{"timestamp": "%(asctime)s", "level": "%(levelname)s", "logger": "%(name)s", "message": "%(message)s"}',
            datefmt="%Y-%m-%d %H:%M:%S",
        )
    elif log_format == "dungeon":
        formatter = DungeonMasterFormatter()
    else:  # console
        formatter = ColoredFormatter()

    # Create Rich handler for beautiful console output
    rich_handler = RichHandler(
        console=console,
        rich_tracebacks=True,
        tracebacks_show_locals=True,
        tracebacks_width=120,
        markup=True,
        show_time=True,
        show_path=True,
        omit_repeated_times=True,
        level=logging.getLevelName(level),
    )
    rich_handler.setFormatter(formatter)

    # Add handler
    logger.addHandler(rich_handler)

    # Prevent propagation to avoid duplicate logs
    logger.propagate = False

    return logger


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with the given name.

    Args:
        name: Logger name (usually __name__)

    Returns:
        Configured logger instance
    """
    return logging.getLogger(name)


# Convenience functions for direct logging
def debug(msg: str, *args: Any, **kwargs: Any) -> None:
    """Log a debug message."""
    logging.debug(msg, *args, **kwargs)


def info(msg: str, *args: Any, **kwargs: Any) -> None:
    """Log an info message."""
    logging.info(msg, *args, **kwargs)


def warning(msg: str, *args: Any, **kwargs: Any) -> None:
    """Log a warning message."""
    logging.warning(msg, *args, **kwargs)


def error(msg: str, *args: Any, **kwargs: Any) -> None:
    """Log an error message."""
    logging.error(msg, *args, **kwargs)


def critical(msg: str, *args: Any, **kwargs: Any) -> None:
    """Log a critical message."""
    logging.critical(msg, *args, **kwargs)
