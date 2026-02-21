from datetime import datetime
from typing import Any, Generic, TypeVar
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

T = TypeVar("T")


class BaseSchema(BaseModel):
    """Base schema with common configuration."""

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
    )


class ErrorResponse(BaseModel):
    """Standard error response schema."""

    error: str = Field(..., description="Error code")
    message: str = Field(..., description="Human-readable error message")
    details: Any | None = Field(default=None, description="Additional error details")


class ValidationErrorDetail(BaseModel):
    """Validation error detail for a single field."""

    loc: list[str | int] = Field(..., description="Location of the error")
    msg: str = Field(..., description="Error message")
    type: str = Field(..., description="Error type")


class ValidationErrorResponse(BaseModel):
    """Validation error response with field details."""

    error: str = Field(default="validation_error")
    message: str = Field(default="Request validation failed")
    details: list[ValidationErrorDetail] = Field(
        default_factory=list,
        description="List of validation errors",
    )


class PaginatedResponse(BaseModel, Generic[T]):
    """Paginated response wrapper."""

    items: list[T] = Field(..., description="List of items")
    total: int = Field(..., description="Total number of items")
    page: int = Field(..., description="Current page number")
    page_size: int = Field(..., description="Number of items per page")
    pages: int = Field(..., description="Total number of pages")


class PaginationParams(BaseModel):
    """Pagination query parameters."""

    page: int = Field(default=1, ge=1, description="Page number")
    page_size: int = Field(default=20, ge=1, le=100, description="Items per page")

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


class TimestampMixin(BaseModel):
    """Mixin for created_at and updated_at fields."""

    created_at: datetime = Field(..., description="Creation timestamp")
    updated_at: datetime = Field(..., description="Last update timestamp")


class IdMixin(BaseModel):
    """Mixin for UUID id field."""

    id: UUID = Field(..., description="Unique identifier")


class SuccessResponse(BaseModel):
    """Generic success response."""

    success: bool = Field(default=True)
    message: str | None = Field(default=None)


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field(..., description="Health status: ok, degraded, unhealthy")
    database: str | None = Field(default=None, description="Database connection status")
    redis: str | None = Field(default=None, description="Redis connection status")
