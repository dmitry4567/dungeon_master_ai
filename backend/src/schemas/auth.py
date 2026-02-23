"""Authentication schemas for request/response validation."""

from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    """Request schema for user registration."""

    email: EmailStr = Field(..., description="User email address")
    password: str = Field(
        ...,
        min_length=8,
        max_length=128,
        description="Password (8-128 characters)",
    )
    name: str = Field(
        ...,
        min_length=2,
        max_length=100,
        description="Display name (2-100 characters)",
    )


class LoginRequest(BaseModel):
    """Request schema for email/password login."""

    email: EmailStr = Field(..., description="User email address")
    password: str = Field(..., description="User password")


class RefreshRequest(BaseModel):
    """Request schema for token refresh."""

    refresh_token: str = Field(..., description="Refresh token")


class AppleSignInRequest(BaseModel):
    """Request schema for Sign in with Apple."""

    identity_token: str = Field(..., description="Apple identity token (JWT)")
    authorization_code: str = Field(..., description="Apple authorization code")
    name: str | None = Field(
        default=None,
        max_length=100,
        description="User name (only provided on first sign-in)",
    )


class TokenResponse(BaseModel):
    """Response schema with authentication tokens."""

    access_token: str = Field(..., description="JWT access token")
    refresh_token: str = Field(..., description="JWT refresh token")
    token_type: str = Field(default="bearer", description="Token type")
    expires_in: int = Field(..., description="Access token expiration time in seconds")


class AuthResponse(BaseModel):
    """Full authentication response with user info and tokens."""

    user_id: str = Field(..., description="User UUID")
    email: str = Field(..., description="User email")
    name: str = Field(..., description="User display name")
    tokens: TokenResponse = Field(..., description="Authentication tokens")
