"""Room Pydantic schemas."""
from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from src.schemas.character import CharacterResponse
from src.schemas.scenario import ScenarioResponse


class CreateRoomRequest(BaseModel):
    """Schema for creating a room."""

    name: str = Field(..., min_length=3, max_length=100, description="Room name")
    scenario_version_id: UUID = Field(..., description="Scenario version to use")
    max_players: int = Field(5, ge=1, le=5, description="Maximum number of players (1 for single player)")


class ReadyRequest(BaseModel):
    """Schema for toggling ready status."""

    character_id: UUID | None = Field(None, description="Character to use (required when ready=True)")
    ready: bool = Field(..., description="Ready status")


class RoomPlayerResponse(BaseModel):
    """Schema for room player in responses."""

    id: UUID
    user_id: UUID
    name: str
    character: CharacterResponse | None = None
    status: str
    is_host: bool

    model_config = ConfigDict(from_attributes=True)


class RoomResponse(BaseModel):
    """Schema for full room details."""

    id: UUID
    name: str
    scenario: ScenarioResponse | None = None
    status: str
    max_players: int
    players: list[RoomPlayerResponse] = []
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class RoomSummaryResponse(BaseModel):
    """Schema for room list summary."""

    id: UUID
    name: str
    scenario_title: str
    host_name: str
    player_count: int
    max_players: int
    status: str
    is_current_user_player: bool = False

    model_config = ConfigDict(from_attributes=True)


class GameSessionResponse(BaseModel):
    """Schema for game session after start."""

    id: UUID
    room_id: UUID
    world_state: dict
    started_at: datetime

    model_config = ConfigDict(from_attributes=True)
