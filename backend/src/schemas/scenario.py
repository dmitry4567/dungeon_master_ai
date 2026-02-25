"""Scenario Pydantic schemas."""
from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class Condition(BaseModel):
    """Schema for a condition."""
    condition: str = Field(..., description="Machine-readable condition ID")
    description: str = Field(..., description="Human-readable description")


class ScenarioScene(BaseModel):
    """Schema for a scene within an act."""
    id: str = Field(..., description="Unique scene identifier")
    name: str = Field(..., description="Human-readable scene name")
    mandatory: bool = Field(...)
    description_for_ai: str = Field(...)
    dm_hints: list[str] = Field(...)
    possible_outcomes: list[str] = Field(...)


class ScenarioAct(BaseModel):
    """Schema for scenario act."""
    id: str = Field(..., description="Unique act identifier")
    name: str = Field(..., description="Human-readable act name")
    entry_condition: Condition = Field(..., description="Condition to enter this act")
    exit_conditions: list[Condition] = Field(..., description="Conditions to exit this act")
    scenes: list[ScenarioScene] = Field(..., description="Scenes in this act")


class ScenarioNPC(BaseModel):
    """Schema for scenario NPC."""

    id: str = Field(..., description="Unique NPC identifier")
    name: str = Field(..., description="NPC name")
    role: str = Field(..., description="NPC role (ally, enemy, neutral, quest_giver, etc.)")
    personality: str = Field(..., description="NPC personality traits")
    speech_style: str = Field(..., description="How the NPC speaks")
    secrets: list[str] = Field(default_factory=list, description="NPC's secrets")
    motivation: str = Field(..., description="NPC's primary motivation")


class ScenarioLocation(BaseModel):
    """Schema for scenario location."""

    id: str = Field(..., description="Unique location identifier")
    name: str = Field(..., description="Location name")
    atmosphere: str = Field(..., description="Location atmosphere and mood")
    rooms: list[str] = Field(default_factory=list, description="Rooms or areas in this location")


class ScenarioFlag(BaseModel):
    """Schema for scenario flag definition."""

    id: str = Field(..., description="Unique flag identifier (machine-readable key)")
    name: str = Field(..., description="Human-readable flag name for display")
    description: str = Field(..., description="Description of what this flag represents")


class ScenarioContent(BaseModel):
    """Schema for scenario content structure."""

    tone: str = Field(
        ...,
        description="Scenario tone (dark_fantasy, heroic, horror, mystery)",
    )
    difficulty: str = Field(
        ...,
        description="Difficulty level (beginner, intermediate, hardcore)",
    )
    players_min: int = Field(..., ge=1, le=5, description="Minimum number of players (1 for single player)")
    players_max: int = Field(..., ge=1, le=5, description="Maximum number of players")
    world_lore: str = Field(..., description="World background and lore")
    acts: list[ScenarioAct] = Field(..., description="Story acts")
    npcs: list[ScenarioNPC] = Field(..., description="Non-player characters")
    locations: list[ScenarioLocation] = Field(..., description="Game locations")
    flags: list[ScenarioFlag] = Field(default_factory=list, description="World flag definitions")


class CreateScenarioRequest(BaseModel):
    """Schema for creating a scenario."""

    description: str = Field(
        ...,
        min_length=10,
        max_length=2000,
        description="Natural language description of the desired scenario",
    )


class RefineScenarioRequest(BaseModel):
    """Schema for refining an existing scenario."""

    prompt: str = Field(
        ...,
        min_length=5,
        max_length=1000,
        description="Refinement instructions",
    )


class ScenarioVersionSummary(BaseModel):
    """Schema for scenario version summary."""

    id: UUID
    version: int
    user_prompt: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ScenarioVersionResponse(BaseModel):
    """Schema for scenario version with full content."""

    id: UUID
    version: int
    content: dict[str, Any]
    validation_errors: list[str] | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ScenarioResponse(BaseModel):
    """Schema for scenario response (without version details)."""

    id: UUID
    title: str
    status: str
    current_version_id: UUID | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ScenarioWithVersionResponse(BaseModel):
    """Schema for scenario with current version details."""

    id: UUID
    title: str
    status: str
    current_version_id: UUID | None
    created_at: datetime
    current_version: ScenarioVersionResponse | None

    model_config = ConfigDict(from_attributes=True)
