"""WebSocket message Pydantic schemas."""
from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class WSMessageType(StrEnum):
    """WebSocket message types."""

    # Client -> Server
    PLAYER_MESSAGE = "player_message"
    PLAYER_JOIN = "player_join"
    PLAYER_LEAVE = "player_leave"
    DICE_ROLL = "dice_roll"  # Player sends their dice roll result

    # Server -> Client
    DM_RESPONSE = "dm_response"
    DM_RESPONSE_CHUNK = "dm_response_chunk"
    DM_RESPONSE_END = "dm_response_end"
    PLAYER_BROADCAST = "player_broadcast"
    SYSTEM_MESSAGE = "system_message"
    STATE_UPDATE = "state_update"
    DICE_REQUEST = "dice_request"  # Server asks player to roll
    DICE_RESULT = "dice_result"  # Broadcast roll result to all
    ERROR = "error"


class WSBaseMessage(BaseModel):
    """Base WebSocket message."""

    type: WSMessageType

    model_config = ConfigDict(use_enum_values=True)


class WSPlayerMessage(WSBaseMessage):
    """Player message sent to server."""

    type: WSMessageType = WSMessageType.PLAYER_MESSAGE
    content: str = Field(..., min_length=1, max_length=2000)


class WSDMResponseChunk(WSBaseMessage):
    """DM response chunk (streaming token)."""

    type: WSMessageType = WSMessageType.DM_RESPONSE_CHUNK
    chunk: str
    message_id: UUID


class WSDMResponseEnd(WSBaseMessage):
    """DM response end marker."""

    type: WSMessageType = WSMessageType.DM_RESPONSE_END
    message_id: UUID
    full_content: str


class WSDMResponse(WSBaseMessage):
    """Complete DM response (non-streaming fallback)."""

    type: WSMessageType = WSMessageType.DM_RESPONSE
    message_id: UUID
    content: str
    dice_result: dict | None = None
    state_delta: dict | None = None


class WSPlayerBroadcast(WSBaseMessage):
    """Player message broadcast to all in room."""

    type: WSMessageType = WSMessageType.PLAYER_BROADCAST
    message_id: UUID
    author_id: UUID
    author_name: str
    character_name: str | None = None
    content: str
    created_at: datetime


class WSSystemMessage(WSBaseMessage):
    """System message to room."""

    type: WSMessageType = WSMessageType.SYSTEM_MESSAGE
    content: str
    created_at: datetime


class WSStateUpdate(WSBaseMessage):
    """World state update notification."""

    type: WSMessageType = WSMessageType.STATE_UPDATE
    world_state: dict


class WSDiceRequest(WSBaseMessage):
    """Request for dice roll from player."""

    type: WSMessageType = WSMessageType.DICE_REQUEST
    request_id: UUID  # Unique ID to match request with response
    target_player_id: UUID  # Player who should roll
    target_player_name: str  # Player name for display
    dice_type: str  # e.g., "d20", "2d6"
    num_dice: int = 1
    modifier: int = 0
    dc: int | None = None
    skill: str | None = None
    reason: str | None = None


class WSDiceRoll(WSBaseMessage):
    """Player's dice roll response."""

    type: WSMessageType = WSMessageType.DICE_ROLL
    request_id: UUID  # Matches the request
    rolls: list[int]  # Individual die results from player


class WSDiceResult(WSBaseMessage):
    """Dice roll result."""

    type: WSMessageType = WSMessageType.DICE_RESULT
    player_id: UUID
    player_name: str
    dice_type: str
    base_roll: int
    modifier: int
    total: int
    dc: int | None = None
    skill: str | None = None
    success: bool | None = None


class WSError(WSBaseMessage):
    """Error message."""

    type: WSMessageType = WSMessageType.ERROR
    error: str
    message: str


class WSPlayerJoin(WSBaseMessage):
    """Player join notification."""

    type: WSMessageType = WSMessageType.PLAYER_JOIN
    player_id: UUID
    player_name: str
    character_name: str | None = None


class WSPlayerLeave(WSBaseMessage):
    """Player leave notification."""

    type: WSMessageType = WSMessageType.PLAYER_LEAVE
    player_id: UUID
    player_name: str
