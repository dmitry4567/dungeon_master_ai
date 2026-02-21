from datetime import UTC, datetime, timedelta
from typing import Any

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from jose import JWTError, jwt

from src.core.config import get_settings

settings = get_settings()

# Argon2id password hasher with recommended parameters
password_hasher = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
)


def hash_password(password: str) -> str:
    """Hash password using Argon2id."""
    return password_hasher.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    """Verify password against hash."""
    try:
        password_hasher.verify(hashed_password, password)
        return True
    except VerifyMismatchError:
        return False


def check_needs_rehash(hashed_password: str) -> bool:
    """Check if password hash needs to be rehashed with new parameters."""
    return password_hasher.check_needs_rehash(hashed_password)


def create_access_token(
    data: dict[str, Any],
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(UTC) + expires_delta
    else:
        expire = datetime.now(UTC) + timedelta(
            minutes=settings.jwt_access_token_expire_minutes
        )

    to_encode.update({
        "exp": expire,
        "iat": datetime.now(UTC),
        "type": "access",
    })

    return jwt.encode(
        to_encode,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def create_refresh_token(
    data: dict[str, Any],
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT refresh token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(UTC) + expires_delta
    else:
        expire = datetime.now(UTC) + timedelta(
            days=settings.jwt_refresh_token_expire_days
        )

    to_encode.update({
        "exp": expire,
        "iat": datetime.now(UTC),
        "type": "refresh",
    })

    return jwt.encode(
        to_encode,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_token(token: str) -> dict[str, Any] | None:
    """Decode and verify JWT token."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        return payload
    except JWTError:
        return None


def verify_token_type(token: str, expected_type: str) -> dict[str, Any] | None:
    """Verify token and check its type."""
    payload = decode_token(token)
    if payload is None:
        return None
    if payload.get("type") != expected_type:
        return None
    return payload


class TokenPayload:
    """Token payload data class."""

    def __init__(self, payload: dict[str, Any]):
        self.sub: str = payload.get("sub", "")
        self.exp: datetime | None = None
        self.iat: datetime | None = None
        self.token_type: str = payload.get("type", "")

        if "exp" in payload:
            self.exp = datetime.fromtimestamp(payload["exp"], tz=UTC)
        if "iat" in payload:
            self.iat = datetime.fromtimestamp(payload["iat"], tz=UTC)

    @property
    def is_expired(self) -> bool:
        """Check if token is expired."""
        if self.exp is None:
            return True
        return datetime.now(UTC) > self.exp

    @classmethod
    def from_token(cls, token: str) -> "TokenPayload | None":
        """Create TokenPayload from token string."""
        payload = decode_token(token)
        if payload is None:
            return None
        return cls(payload)
