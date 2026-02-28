from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from src.schemas.tts import TTSStreamRequest, TTSStatusResponse
from src.services.tts_service import TTSService, get_tts_service

router = APIRouter(prefix="/tts", tags=["TTS"])


@router.post("/stream")
async def stream_tts(
    request: TTSStreamRequest,
    tts_service: TTSService = Depends(get_tts_service),
):
    """
    Streams MP3 audio generated from text using ElevenLabs API.
    Response is chunked audio/mpeg stream.
    """
    return StreamingResponse(
        tts_service.stream_tts(request.text),
        media_type="audio/mpeg"
    )


@router.get("/status", response_model=TTSStatusResponse)
async def get_tts_status(
    tts_service: TTSService = Depends(get_tts_service),
):
    """
    Returns the current status of TTS service.
    Used to check if TTS is available before showing UI.
    """
    available, error_message = await tts_service.check_availability()
    return TTSStatusResponse(available=available, message=error_message)
