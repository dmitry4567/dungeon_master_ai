"""Session Pydantic schemas."""
from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class SessionMessageResponse(BaseModel):
    """Schema for session message in responses."""

    id: UUID
    author_id: UUID | None = None
    author_name: str | None = None
    role: str
    content: str
    dice_result: dict | None = None
    state_delta: dict | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class GameSessionResponse(BaseModel):
    """Schema for full game session details."""

    id: UUID
    room_id: UUID
    world_state: dict
    started_at: datetime
    ended_at: datetime | None = None
    messages: list[SessionMessageResponse] = []

    model_config = ConfigDict(from_attributes=True)


class GameSessionSummaryResponse(BaseModel):
    """Schema for game session summary."""

    id: UUID
    room_id: UUID
    room_name: str
    player_count: int
    started_at: datetime
    ended_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class SendMessageRequest(BaseModel):
    """Schema for sending a player message."""

    content: str = Field(..., min_length=1, max_length=2000, description="Message content")


class WorldStateResponse(BaseModel):
    """Schema for world state."""

    current_act: str | None = None
    current_scene: str | None = None
    current_location: str | None = None
    completed_scenes: list[str] = []
    flags: dict = {}
    combat_active: bool = False
    turn_order: list[str] = []

    model_config = ConfigDict(from_attributes=True)
