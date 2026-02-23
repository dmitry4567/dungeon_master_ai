"""Character service for CRUD operations."""
from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.character import Character
from src.schemas.character import CharacterCreate, CharacterUpdate
from src.services.dnd_validator import validate_character

if TYPE_CHECKING:
    pass


class CharacterValidationError(Exception):
    """Raised when character validation fails."""

    def __init__(self, errors: list[dict[str, str]]) -> None:
        self.errors = errors
        super().__init__(f"Character validation failed: {errors}")


class CharacterNotFoundError(Exception):
    """Raised when character is not found."""

    pass


class CharacterService:
    """Service for character CRUD operations."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(
        self,
        user_id: uuid.UUID,
        data: CharacterCreate,
    ) -> Character:
        """
        Create a new character.

        Args:
            user_id: Owner's user ID
            data: Character creation data

        Returns:
            Created character

        Raises:
            CharacterValidationError: If D&D 5e validation fails
        """
        # Validate against D&D 5e rules
        validation_result = validate_character(
            name=data.name,
            character_class=data.character_class,
            race=data.race,
            level=data.level,
            ability_scores=data.ability_scores.model_dump(),
            backstory=data.backstory,
        )

        if not validation_result.is_valid:
            errors = [
                {"field": e.field, "message": e.message}
                for e in validation_result.errors
            ]
            raise CharacterValidationError(errors)

        character = Character(
            user_id=user_id,
            name=data.name,
            character_class=data.character_class,
            race=data.race,
            level=data.level,
            ability_scores=data.ability_scores.model_dump(),
            backstory=data.backstory,
        )

        self.db.add(character)
        await self.db.commit()
        await self.db.refresh(character)
        return character

    async def get_by_id(
        self,
        character_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> Character:
        """
        Get a character by ID.

        Args:
            character_id: Character ID
            user_id: Owner's user ID (for authorization)

        Returns:
            Character if found and owned by user

        Raises:
            CharacterNotFoundError: If character not found or not owned by user
        """
        result = await self.db.execute(
            select(Character).where(
                Character.id == character_id,
                Character.user_id == user_id,
            )
        )
        character = result.scalar_one_or_none()

        if character is None:
            raise CharacterNotFoundError(f"Character {character_id} not found")

        return character

    async def get_all_for_user(self, user_id: uuid.UUID) -> list[Character]:
        """
        Get all characters for a user.

        Args:
            user_id: Owner's user ID

        Returns:
            List of characters owned by user
        """
        result = await self.db.execute(
            select(Character)
            .where(Character.user_id == user_id)
            .order_by(Character.created_at.desc())
        )
        return list(result.scalars().all())

    async def update(
        self,
        character_id: uuid.UUID,
        user_id: uuid.UUID,
        data: CharacterUpdate,
    ) -> Character:
        """
        Update a character.

        Args:
            character_id: Character ID
            user_id: Owner's user ID (for authorization)
            data: Fields to update

        Returns:
            Updated character

        Raises:
            CharacterNotFoundError: If character not found or not owned by user
        """
        character = await self.get_by_id(character_id, user_id)

        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(character, field, value)

        await self.db.commit()
        await self.db.refresh(character)
        return character

    async def delete(
        self,
        character_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> None:
        """
        Delete a character.

        Args:
            character_id: Character ID
            user_id: Owner's user ID (for authorization)

        Raises:
            CharacterNotFoundError: If character not found or not owned by user
        """
        character = await self.get_by_id(character_id, user_id)
        await self.db.delete(character)
        await self.db.commit()

    async def exists(self, character_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        """
        Check if a character exists and belongs to user.

        Args:
            character_id: Character ID
            user_id: User ID to check ownership

        Returns:
            True if character exists and belongs to user
        """
        result = await self.db.execute(
            select(Character.id).where(
                Character.id == character_id,
                Character.user_id == user_id,
            )
        )
        return result.scalar_one_or_none() is not None
