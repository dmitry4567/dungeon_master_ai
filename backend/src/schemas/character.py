"""Character Pydantic schemas."""
from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class AbilityScores(BaseModel):
    """D&D 5e ability scores."""

    strength: int = Field(..., ge=1, le=20, description="Strength score (1-20)")
    dexterity: int = Field(..., ge=1, le=20, description="Dexterity score (1-20)")
    constitution: int = Field(..., ge=1, le=20, description="Constitution score (1-20)")
    intelligence: int = Field(..., ge=1, le=20, description="Intelligence score (1-20)")
    wisdom: int = Field(..., ge=1, le=20, description="Wisdom score (1-20)")
    charisma: int = Field(..., ge=1, le=20, description="Charisma score (1-20)")


class CharacterCreate(BaseModel):
    """Schema for creating a new character."""

    name: str = Field(..., min_length=1, max_length=100, description="Character name")
    character_class: str = Field(
        ...,
        alias="class",
        description="D&D 5e class (barbarian, bard, cleric, druid, fighter, monk, paladin, ranger, rogue, sorcerer, warlock, wizard)",
    )
    race: str = Field(
        ...,
        description="D&D 5e race (dragonborn, dwarf, elf, gnome, half-elf, halfling, half-orc, human, tiefling)",
    )
    ability_scores: AbilityScores = Field(..., description="Character ability scores")
    level: int = Field(default=1, ge=1, le=20, description="Character level (1-20)")
    backstory: str | None = Field(
        default=None, max_length=5000, description="Character backstory"
    )

    model_config = ConfigDict(populate_by_name=True)


class CharacterUpdate(BaseModel):
    """Schema for updating a character."""

    name: str | None = Field(default=None, min_length=1, max_length=100)
    backstory: str | None = Field(default=None, max_length=5000)
    level: int | None = Field(default=None, ge=1, le=20)

    model_config = ConfigDict(populate_by_name=True)


class CharacterResponse(BaseModel):
    """Schema for character response."""

    id: UUID
    name: str
    character_class: str = Field(..., serialization_alias="class")
    race: str
    level: int
    ability_scores: AbilityScores
    backstory: str | None
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
        populate_by_name=True,
    )


class CharacterListResponse(BaseModel):
    """Schema for list of characters."""

    characters: list[CharacterResponse]
    total: int
