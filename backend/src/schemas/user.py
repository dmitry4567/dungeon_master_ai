"""User schemas for request/response validation."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from src.schemas.common import BaseSchema


class UserResponse(BaseSchema):
    """Response schema for user data."""

    id: UUID = Field(..., description="User UUID")
    email: EmailStr = Field(..., description="User email address")
    name: str = Field(..., description="Display name")
    avatar_url: str | None = Field(default=None, description="Avatar URL")
    created_at: datetime = Field(..., description="Account creation timestamp")
    updated_at: datetime = Field(..., description="Last profile update timestamp")


class UserUpdate(BaseModel):
    """Request schema for updating user profile."""

    name: str | None = Field(
        default=None,
        min_length=2,
        max_length=100,
        description="New display name (2-100 characters)",
    )
    avatar_url: str | None = Field(
        default=None,
        max_length=500,
        description="New avatar URL",
    )


class UserBrief(BaseSchema):
    """Brief user info for embedding in other responses."""

    id: UUID = Field(..., description="User UUID")
    name: str = Field(..., description="Display name")
    avatar_url: str | None = Field(default=None, description="Avatar URL")
