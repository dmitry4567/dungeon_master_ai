"""User service for profile management."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.logging import get_logger
from src.models.user import User
from src.schemas.user import UserUpdate

logger = get_logger(__name__)


class UserNotFoundError(Exception):
    """User not found."""

    def __init__(self):
        self.code = "user_not_found"
        self.message = "User not found"
        super().__init__(self.message)


class UserService:
    """Service for user profile operations."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: UUID) -> User:
        """Get user by ID."""
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if not user:
            raise UserNotFoundError()

        return user

    async def get_by_email(self, email: str) -> User | None:
        """Get user by email (returns None if not found)."""
        result = await self.db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def update(self, user_id: UUID, data: UserUpdate) -> User:
        """Update user profile."""
        user = await self.get_by_id(user_id)

        update_data = data.model_dump(exclude_unset=True, exclude_none=True)

        if not update_data:
            return user

        for field, value in update_data.items():
            setattr(user, field, value)

        await self.db.commit()
        await self.db.refresh(user)

        logger.info(
            "User profile updated: user_id=%s, fields=%s",
            str(user_id),
            list(update_data.keys()),
        )

        return user

    async def delete(self, user_id: UUID) -> None:
        """Delete user account."""
        user = await self.get_by_id(user_id)
        await self.db.delete(user)
        await self.db.commit()

        logger.info("User deleted: user_id=%s", str(user_id))
