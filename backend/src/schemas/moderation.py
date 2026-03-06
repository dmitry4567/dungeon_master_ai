"""Pydantic schemas for content moderation events."""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


class ModerationAction(str, Enum):
    """Action taken by moderation system."""

    ALLOWED = "allowed"
    BLOCKED = "blocked"
    FLAGGED = "flagged"
    REDACTED = "redacted"


class ModerationCategory(str, Enum):
    """Category of moderation flag."""

    VIOLENCE = "violence"
    HATE_SPEECH = "hate_speech"
    SEXUAL_CONTENT = "sexual_content"
    SELF_HARM = "self_harm"
    HARASSMENT = "harassment"
    SPAM = "spam"
    OTHER = "other"


class ModerationEvent(BaseModel):
    """Event logged when content moderation is triggered."""

    event_id: UUID = Field(description="Unique event identifier")
    session_id: UUID | None = Field(default=None, description="Game session ID")
    user_id: UUID | None = Field(default=None, description="User who sent the content")
    room_id: UUID | None = Field(default=None, description="Room where event occurred")
    content_type: str = Field(description="Type of content: player_message, dm_response, scenario")
    action: ModerationAction = Field(description="Action taken by moderation")
    categories: list[ModerationCategory] = Field(
        default_factory=list,
        description="Moderation categories triggered",
    )
    confidence: float | None = Field(
        default=None,
        ge=0.0,
        le=1.0,
        description="Confidence score for moderation decision",
    )
    original_content_preview: str | None = Field(
        default=None,
        max_length=200,
        description="First 200 chars of original content for auditing",
    )
    timestamp: datetime = Field(description="When moderation occurred")
    provider: str = Field(default="anthropic", description="Moderation provider")
    metadata: dict = Field(default_factory=dict, description="Additional metadata")


class ModerationResult(BaseModel):
    """Result of a moderation check."""

    allowed: bool = Field(description="Whether content is allowed")
    action: ModerationAction = Field(description="Action to take")
    categories: list[ModerationCategory] = Field(default_factory=list)
    confidence: float | None = None
    reason: str | None = Field(default=None, description="Human-readable reason if blocked")
