"""Voice schemas for TTS and Agora voice chat operations."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from src.schemas.common import BaseSchema


class TTSRequest(BaseModel):
    """Request schema for text-to-speech conversion."""

    text: str = Field(..., min_length=1, max_length=5000, description="Text to convert to speech")
    voice: str | None = Field(
        default=None,
        max_length=50,
        description="Voice ID (optional, uses default if not specified)",
    )
    language: str | None = Field(
        default="ru",
        max_length=10,
        description="Language code (default: ru)",
    )


class TTSResponse(BaseSchema):
    """Response schema for TTS operation."""

    audio_url: str = Field(..., description="URL to the generated audio file")
    duration_seconds: float = Field(..., description="Audio duration in seconds")
    text: str = Field(..., description="Original text that was converted")


class VoiceSession(BaseSchema):
    """Voice session for tracking TTS history."""

    id: UUID = Field(..., description="Session UUID")
    user_id: UUID = Field(..., description="User UUID")
    text: str = Field(..., description="Text content")
    audio_url: str = Field(..., description="Audio file URL")
    direction: str = Field(..., description="Direction: 'tts'")
    created_at: str = Field(..., description="Creation timestamp")


# Agora Voice Chat Schemas


class VoiceTokenResponse(BaseSchema):
    """Response schema for Agora voice token."""

    token: str = Field(..., description="Agora RTC token for joining the voice channel")
    channel_name: str = Field(..., description="Agora channel name (equals room_id)")
    uid: int = Field(..., description="Numeric uid for this user in the Agora channel")
    app_id: str = Field(..., description="Agora App ID needed by client SDK initialization")
    expires_at: datetime = Field(..., description="UTC datetime when the token expires")
