"""Authentication service for user registration, login, and token management."""

from __future__ import annotations

import logging
from uuid import UUID

import httpx
from jose import jwt as jose_jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.config import get_settings
from src.core.security import (
    check_needs_rehash,
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
    verify_token_type,
)
from src.models.user import User
from src.schemas.auth import (
    AppleSignInRequest,
    AuthResponse,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
)

logger = logging.getLogger(__name__)
settings = get_settings()


class AuthError(Exception):
    """Base authentication error."""

    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


class EmailAlreadyExistsError(AuthError):
    """Email already registered."""

    def __init__(self):
        super().__init__("email_exists", "Email already registered")


class InvalidCredentialsError(AuthError):
    """Invalid email or password."""

    def __init__(self):
        super().__init__("invalid_credentials", "Invalid email or password")


class InvalidTokenError(AuthError):
    """Invalid or expired token."""

    def __init__(self):
        super().__init__("invalid_token", "Invalid or expired token")


class AppleAuthError(AuthError):
    """Apple Sign In verification failed."""

    def __init__(self, message: str = "Apple Sign In failed"):
        super().__init__("apple_auth_error", message)


class AuthService:
    """Service for authentication operations."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register(self, request: RegisterRequest) -> AuthResponse:
        """Register a new user with email and password."""
        existing = await self._get_user_by_email(request.email)
        if existing:
            raise EmailAlreadyExistsError()

        password_hash = hash_password(request.password)

        user = User(
            email=request.email,
            password_hash=password_hash,
            name=request.name,
        )

        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)

        logger.info("User registered", extra={"user_id": str(user.id), "email": user.email})

        return self._create_auth_response(user)

    async def login(self, request: LoginRequest) -> AuthResponse:
        """Authenticate user with email and password."""
        user = await self._get_user_by_email(request.email)
        if not user or not user.password_hash:
            raise InvalidCredentialsError()

        if not verify_password(request.password, user.password_hash):
            raise InvalidCredentialsError()

        if check_needs_rehash(user.password_hash):
            user.password_hash = hash_password(request.password)
            await self.db.commit()

        logger.info("User logged in", extra={"user_id": str(user.id)})

        return self._create_auth_response(user)

    async def refresh(self, refresh_token: str) -> TokenResponse:
        """Refresh access token using refresh token."""
        payload = verify_token_type(refresh_token, "refresh")
        if not payload:
            raise InvalidTokenError()

        user_id = payload.get("sub")
        if not user_id:
            raise InvalidTokenError()

        user = await self._get_user_by_id(UUID(user_id))
        if not user:
            raise InvalidTokenError()

        logger.info("Token refreshed", extra={"user_id": str(user.id)})

        return self._create_token_response(user)

    async def apple_sign_in(self, request: AppleSignInRequest) -> AuthResponse:
        """Authenticate or register user via Apple Sign In."""
        apple_user_id, email = await self._verify_apple_token(request.identity_token)

        user = await self._get_user_by_apple_id(apple_user_id)

        if user:
            logger.info("User signed in with Apple", extra={"user_id": str(user.id)})
            return self._create_auth_response(user)

        existing_by_email = await self._get_user_by_email(email) if email else None
        if existing_by_email:
            existing_by_email.apple_user_id = apple_user_id
            await self.db.commit()
            await self.db.refresh(existing_by_email)
            logger.info(
                "Linked Apple ID to existing user",
                extra={"user_id": str(existing_by_email.id)},
            )
            return self._create_auth_response(existing_by_email)

        name = request.name or email.split("@")[0] if email else "Apple User"

        user = User(
            email=email or f"{apple_user_id}@privaterelay.appleid.com",
            apple_user_id=apple_user_id,
            name=name,
            password_hash=None,
        )

        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)

        logger.info(
            "User registered via Apple Sign In",
            extra={"user_id": str(user.id)},
        )

        return self._create_auth_response(user)

    async def _verify_apple_token(self, identity_token: str) -> tuple[str, str | None]:
        """Verify Apple identity token and extract user info."""
        try:
            unverified_header = jose_jwt.get_unverified_header(identity_token)
            kid = unverified_header.get("kid")

            async with httpx.AsyncClient() as client:
                response = await client.get(
                    "https://appleid.apple.com/auth/keys",
                    timeout=10.0,
                )
                response.raise_for_status()
                apple_keys = response.json()

            key = next(
                (k for k in apple_keys.get("keys", []) if k.get("kid") == kid),
                None,
            )
            if not key:
                raise AppleAuthError("Apple public key not found")

            from jose import jwk

            public_key = jwk.construct(key)

            payload = jose_jwt.decode(
                identity_token,
                public_key,
                algorithms=["RS256"],
                audience=settings.apple_client_id,
                issuer="https://appleid.apple.com",
            )

            apple_user_id = payload.get("sub")
            email = payload.get("email")

            if not apple_user_id:
                raise AppleAuthError("Invalid Apple token: missing user ID")

            return apple_user_id, email

        except jose_jwt.JWTError as e:
            logger.warning("Apple token verification failed", extra={"error": str(e)})
            raise AppleAuthError(f"Token verification failed: {str(e)}") from e
        except httpx.HTTPError as e:
            logger.error("Failed to fetch Apple public keys", extra={"error": str(e)})
            raise AppleAuthError("Failed to verify Apple token") from e

    async def _get_user_by_email(self, email: str) -> User | None:
        """Get user by email."""
        result = await self.db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def _get_user_by_id(self, user_id: UUID) -> User | None:
        """Get user by ID."""
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def _get_user_by_apple_id(self, apple_user_id: str) -> User | None:
        """Get user by Apple user ID."""
        result = await self.db.execute(
            select(User).where(User.apple_user_id == apple_user_id)
        )
        return result.scalar_one_or_none()

    def _create_auth_response(self, user: User) -> AuthResponse:
        """Create auth response with user info and tokens."""
        tokens = self._create_token_response(user)
        return AuthResponse(
            user_id=str(user.id),
            email=user.email,
            name=user.name,
            tokens=tokens,
        )

    def _create_token_response(self, user: User) -> TokenResponse:
        """Create token response."""
        access_token = create_access_token({"sub": str(user.id)})
        refresh_token = create_refresh_token({"sub": str(user.id)})

        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.jwt_access_token_expire_minutes * 60,
        )
