"""Voice service for TTS and Agora voice chat operations."""

from __future__ import annotations

import time
import uuid
from datetime import datetime, timezone
from typing import Protocol
from uuid import UUID

from src.core.logging import get_logger
from src.schemas.voice import TTSRequest, TTSResponse, VoiceTokenResponse

logger = get_logger(__name__)


class VoiceServiceError(Exception):
    """Voice service error."""

    def __init__(self, message: str, code: str = "voice_error"):
        self.message = message
        self.code = code
        super().__init__(self.message)


class TTSProvider(Protocol):
    """Protocol for TTS providers."""

    async def synthesize(self, text: str, voice: str | None = None, language: str = "ru") -> bytes:
        """Synthesize speech from text."""
        ...


class VoiceService:
    """Service for TTS operations."""

    def __init__(
        self,
        tts_provider: TTSProvider | None = None,
    ):
        self._tts_provider = tts_provider

    async def text_to_speech(self, request: TTSRequest, user_id: str) -> TTSResponse:
        """Convert text to speech."""
        try:
            # Generate audio using TTS provider
            if self._tts_provider is None:
                # Mock response for development
                audio_data = b""  # Empty audio for mock
                duration = len(request.text) * 0.1  # Rough estimate
            else:
                audio_data = await self._tts_provider.synthesize(
                    text=request.text,
                    voice=request.voice,
                    language=request.language or "ru",
                )
                duration = len(audio_data) / 16000  # Estimate based on sample rate

            # Upload audio to storage
            audio_filename = f"voice/{user_id}/{uuid.uuid4()}.mp3"
            audio_url = f"https://storage.example.com/{audio_filename}"

            return TTSResponse(
                audio_url=audio_url,
                duration_seconds=duration,
                text=request.text,
            )

        except Exception as e:
            logger.exception("TTS conversion failed")
            raise VoiceServiceError(f"TTS conversion failed: {str(e)}")


# Agora Voice Chat Functions


def get_agora_uid(user_id: UUID | str) -> int:
    """
    Convert UUID to numeric uid for Agora.
    Returns a deterministic value in range [0, 2^31-1].
    """
    return abs(hash(str(user_id))) % (2**31)


def generate_voice_token(
    app_id: str,
    app_certificate: str,
    channel_name: str,
    uid: int,
    expire_seconds: int = 14400,
) -> tuple[str, datetime]:
    """
    Generate an Agora RTC token for voice channel access.

    Args:
        app_id: Agora App ID
        app_certificate: Agora App Certificate
        channel_name: Channel name (room_id)
        uid: Numeric user ID for Agora
        expire_seconds: Token validity in seconds (default 4 hours)

    Returns:
        Tuple of (token, expires_at datetime)
    """
    from agora_token_builder import RtcTokenBuilder

    expire_ts = int(time.time()) + expire_seconds
    expires_at = datetime.fromtimestamp(expire_ts, tz=timezone.utc)

    # Role_Publisher = 1 (broadcaster can send and receive audio)
    token = RtcTokenBuilder.buildTokenWithUid(
        app_id,
        app_certificate,
        channel_name,
        uid,
        1,  # Role_Publisher
        expire_ts,
    )

    logger.info(
        "token_generated: channel_name=%s, uid=%s, expires_at=%s",
        channel_name,
        uid,
        expires_at.isoformat(),
    )

    return token, expires_at


def create_voice_token_response(
    app_id: str,
    app_certificate: str,
    room_id: str,
    user_id: UUID | str,
    expire_seconds: int = 14400,
) -> VoiceTokenResponse:
    """
    Create a complete VoiceTokenResponse for a user joining a room's voice channel.

    Args:
        app_id: Agora App ID
        app_certificate: Agora App Certificate
        room_id: Room UUID as string (used as channel name)
        user_id: User UUID
        expire_seconds: Token validity in seconds

    Returns:
        VoiceTokenResponse with all required fields
    """
    uid = get_agora_uid(user_id)
    token, expires_at = generate_voice_token(
        app_id=app_id,
        app_certificate=app_certificate,
        channel_name=room_id,
        uid=uid,
        expire_seconds=expire_seconds,
    )

    logger.info(
        "voice_token_response_created: user_id=%s, room_id=%s, uid=%s, expires_at=%s",
        str(user_id),
        room_id,
        uid,
        expires_at.isoformat(),
    )

    return VoiceTokenResponse(
        token=token,
        channel_name=room_id,
        uid=uid,
        app_id=app_id,
        expires_at=expires_at,
    )
