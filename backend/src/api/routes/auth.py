"""Authentication routes."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from src.api.dependencies import DbSession
from src.schemas.auth import (
    AppleSignInRequest,
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from src.schemas.common import ErrorResponse
from src.services.auth_service import (
    AppleAuthError,
    AuthService,
    EmailAlreadyExistsError,
    InvalidCredentialsError,
    InvalidTokenError,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        409: {"model": ErrorResponse, "description": "Email already registered"},
        400: {"model": ErrorResponse, "description": "Validation error"},
    },
)
async def register(
    request: RegisterRequest,
    db: DbSession,
) -> AuthResponse:
    """Register a new user with email and password."""
    auth_service = AuthService(db)

    try:
        return await auth_service.register(request)
    except EmailAlreadyExistsError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": e.code, "message": e.message},
        )


@router.post(
    "/login",
    response_model=AuthResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Invalid credentials"},
    },
)
async def login(
    request: LoginRequest,
    db: DbSession,
) -> AuthResponse:
    """Authenticate user with email and password."""
    auth_service = AuthService(db)

    try:
        return await auth_service.login(request)
    except InvalidCredentialsError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": e.code, "message": e.message},
        )


@router.post(
    "/refresh",
    response_model=TokenResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Invalid or expired token"},
    },
)
async def refresh(
    request: RefreshRequest,
    db: DbSession,
) -> TokenResponse:
    """Refresh access token using refresh token."""
    auth_service = AuthService(db)

    try:
        return await auth_service.refresh(request.refresh_token)
    except InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": e.code, "message": e.message},
        )


@router.post(
    "/apple",
    response_model=AuthResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Apple authentication failed"},
    },
)
async def apple_sign_in(
    request: AppleSignInRequest,
    db: DbSession,
) -> AuthResponse:
    """Authenticate or register user via Sign in with Apple."""
    auth_service = AuthService(db)

    try:
        return await auth_service.apple_sign_in(request)
    except AppleAuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": e.code, "message": e.message},
        )
