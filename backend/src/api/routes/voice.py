"""Voice API routes for TTS operations."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from src.api.dependencies import get_current_user, get_voice_service
from src.models.user import User
from src.schemas.voice import TTSRequest, TTSResponse
from src.services.voice_service import VoiceService, VoiceServiceError

router = APIRouter(prefix="/voice", tags=["Voice"])


@router.post(
    "/tts",
    response_model=TTSResponse,
    status_code=status.HTTP_200_OK,
    summary="Text-to-Speech",
    description="Convert text to speech audio",
)
async def text_to_speech(
    request: TTSRequest,
    current_user: User = Depends(get_current_user),
    voice_service: VoiceService = Depends(get_voice_service),
) -> TTSResponse:
    """Convert text to speech.

    - **text**: Text to convert (max 5000 characters)
    - **voice**: Optional voice ID
    - **language**: Language code (default: ru)

    Returns URL to generated audio file.
    """
    try:
        result = await voice_service.text_to_speech(request, str(current_user.id))
        return result
    except VoiceServiceError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"code": e.code, "message": e.message},
        )
