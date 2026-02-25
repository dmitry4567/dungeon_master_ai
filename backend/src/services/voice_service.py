"""Voice service for TTS operations."""

from __future__ import annotations

import uuid
from typing import Protocol

from src.core.logging import get_logger
from src.schemas.voice import TTSRequest, TTSResponse

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
