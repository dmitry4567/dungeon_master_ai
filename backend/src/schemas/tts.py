from pydantic import BaseModel, Field


class TTSStreamRequest(BaseModel):
    """Request for streaming TTS generation."""

    text: str = Field(
        ...,
        min_length=1,
        max_length=10000,
        description="Text to convert to speech"
    )
    message_id: str | None = Field(
        default=None,
        description="Optional message ID for tracking"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "text": "Вы входите в тёмную пещеру...",
                "message_id": "msg_123"
            }
        }


class TTSErrorResponse(BaseModel):
    """Error response for TTS requests."""

    error_code: str = Field(
        ...,
        description="Error code: rate_limit, quota_exceeded, api_error, validation_error"
    )
    message: str = Field(
        ...,
        description="User-friendly error message in Russian"
    )
    retry_after: int | None = Field(
        default=None,
        description="Seconds to wait before retry (for rate_limit)"
    )


class TTSStatusResponse(BaseModel):
    """TTS service status."""

    available: bool = Field(
        ...,
        description="Whether TTS service is currently available"
    )
    message: str | None = Field(
        default=None,
        description="Message explaining why TTS is unavailable"
    )
