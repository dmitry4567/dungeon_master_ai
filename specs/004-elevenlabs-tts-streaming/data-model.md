# Data Model: ElevenLabs TTS Streaming

**Feature**: 004-elevenlabs-tts-streaming
**Date**: 2026-02-27

## Overview

Данная функция не требует новых таблиц в БД. Все данные обрабатываются в runtime (состояние воспроизведения хранится только на клиенте).

---

## Client-Side Entities

### TTSState (Freezed)

Состояние воспроизведения TTS на клиенте.

```dart
@freezed
class TTSState with _$TTSState {
  const factory TTSState({
    /// Текущий статус воспроизведения
    @Default(TTSStatus.idle) TTSStatus status,

    /// ID сообщения, которое сейчас воспроизводится
    String? currentMessageId,

    /// Сообщение об ошибке (если status == error)
    String? errorMessage,

    /// Флаг: было ли воспроизведение до прерывания (звонок, Siri)
    @Default(false) bool wasPlayingBeforeInterruption,
  }) = _TTSState;
}
```

### TTSStatus (Enum)

```dart
enum TTSStatus {
  /// Ничего не воспроизводится
  idle,

  /// Загрузка/буферизация аудио
  loading,

  /// Аудио воспроизводится
  playing,

  /// Аудио приостановлено (прерывание)
  paused,

  /// Ошибка воспроизведения
  error,
}
```

### State Transitions

```
idle ──(play)──> loading ──(audio ready)──> playing
  ↑                                            │
  │                                            │
  └──────────(stop/complete/error)─────────────┘

playing ──(interruption)──> paused ──(resume)──> playing
```

---

## Server-Side Entities

### TTSStreamRequest (Pydantic)

Запрос на генерацию речи от клиента.

```python
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
```

### TTSErrorResponse (Pydantic)

Ответ при ошибке TTS.

```python
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
```

### Error Codes

| Code | HTTP Status | User Message |
|------|-------------|--------------|
| `rate_limit` | 429 | "Превышен лимит прослушиваний, попробуйте позже (через минуту)" |
| `quota_exceeded` | 402 | "Озвучка временно недоступна" |
| `api_error` | 502 | "Ошибка сервиса озвучки, попробуйте позже" |
| `validation_error` | 400 | "Некорректный текст для озвучки" |
| `text_too_long` | 400 | "Сообщение слишком длинное" |

---

## Configuration Entities

### ElevenLabs Settings (Backend Config)

```python
class Settings(BaseSettings):
    # ... existing settings ...

    # ElevenLabs TTS
    elevenlabs_api_key: str = Field(
        default="",
        description="ElevenLabs API key"
    )

    elevenlabs_voice_id: str = Field(
        default="",
        description="Voice ID for Russian female voice"
    )

    elevenlabs_model_id: str = Field(
        default="eleven_multilingual_v2",
        description="ElevenLabs model ID"
    )

    tts_max_text_length: int = Field(
        default=5000,
        description="Maximum text length per TTS request"
    )

    tts_chunk_size: int = Field(
        default=2500,
        description="Text chunk size for long messages"
    )
```

---

## Relationships

```
┌─────────────────────┐
│     Message         │
│  (existing entity)  │
│                     │
│  - id: String       │
│  - content: String  │
│  - role: MessageRole│
└─────────┬───────────┘
          │
          │ referenced by
          │
┌─────────▼───────────┐
│     TTSState        │
│   (client-side)     │
│                     │
│  - currentMessageId │◄─── one active at a time
│  - status           │
└─────────────────────┘
```

---

## Validation Rules

### Text Validation (Server)

1. **Length**: 1-10000 characters (после очистки от Markdown)
2. **Content**: Не должен содержать только whitespace
3. **Encoding**: UTF-8

### Text Preprocessing (Server)

1. Strip Markdown: `**bold**` → `bold`, `*italic*` → `italic`
2. Remove DICE tags: `[DICE: d20+2 DC:15]` → ""
3. Normalize whitespace: multiple spaces → single space
4. Trim leading/trailing whitespace

### Chunking Rules

Для текстов > `tts_chunk_size`:
1. Разбить по границам предложений (`.`, `!`, `?`)
2. Если предложение > chunk_size, разбить по `,` или `;`
3. Если всё ещё > chunk_size, разбить по словам
4. Chunks воспроизводятся последовательно без пауз
