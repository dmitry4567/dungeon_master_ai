# Research: ElevenLabs TTS Streaming Integration

**Feature**: 004-elevenlabs-tts-streaming
**Date**: 2026-02-27

## Executive Summary

Исследование подтверждает техническую возможность интеграции ElevenLabs TTS streaming в существующую архитектуру проекта. Рекомендуется использовать HTTP streaming через FastAPI backend с воспроизведением через just_audio на клиенте.

---

## 1. ElevenLabs API Integration

### Decision: HTTP Streaming Endpoint
**Rationale**: HTTP streaming проще в реализации, не требует WebSocket-прокси, лучше подходит для pre-generated контента (сообщения DM).

**Alternatives considered**:
- WebSocket API — отклонён, избыточная сложность для данного use case
- Direct API call — отклонён, нарушает конституцию (AI только на бэкенде)

### Endpoint Details

```
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream
Content-Type: application/json
xi-api-key: {API_KEY}

{
    "text": "Текст для озвучки",
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
        "stability": 0.5,
        "similarity_boost": 0.75
    },
    "output_format": "mp3_44100_128"
}
```

**Response**: `application/octet-stream` (chunked MP3 audio)

### Text Limits
- **Subscriber tier**: до 5,000 символов на запрос
- **Стратегия для длинных текстов**: разбиение на части по 2,000-3,000 символов по границам предложений

### Voice Selection for Russian Female
Необходимо получить voice_id через API:
```python
GET /v1/voices
# Фильтр: language_code="ru", gender="female"
```

Популярные варианты: Bella, Anna (для нарратива)

---

## 2. Backend Architecture

### Decision: FastAPI StreamingResponse Proxy
**Rationale**: Соответствует конституции (API ключи на сервере), позволяет контролировать rate limits, добавлять аутентификацию.

### Implementation Pattern

```python
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
import httpx

@router.post("/api/v1/tts/stream")
async def stream_tts(request: TTSStreamRequest, user: User = Depends(get_current_user)):
    async def generate():
        async with httpx.AsyncClient() as client:
            async with client.stream(
                "POST",
                f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream",
                json={"text": request.text, ...},
                headers={"xi-api-key": settings.elevenlabs_api_key}
            ) as response:
                async for chunk in response.aiter_bytes(chunk_size=4096):
                    yield chunk

    return StreamingResponse(generate(), media_type="audio/mpeg")
```

### Error Handling

| HTTP Code | Meaning | Action |
|-----------|---------|--------|
| 429 | Rate limit | Return "Превышен лимит, попробуйте через минуту" |
| 401 | Invalid API key | Log error, return "Озвучка недоступна" |
| 422 | Validation error | Return specific error message |
| 500+ | Server error | Retry once, then return error |

---

## 3. Flutter Audio Playback

### Decision: just_audio Package
**Rationale**: Лучшая поддержка HTTP streaming, background playback, interruption handling. 641k+ downloads, активная поддержка.

**Alternatives considered**:
- audioplayers — отклонён, не поддерживает background audio нативно
- audio_service — отклонён, слишком низкоуровневый для данной задачи

### Required Packages

```yaml
dependencies:
  just_audio: ^0.9.36
  audio_session: ^0.1.18
```

### iOS Configuration

**Info.plist additions**:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### Audio Session Setup

```dart
final session = await AudioSession.instance;
await session.configure(AudioSessionConfiguration.music());

session.interruptionEventStream.listen((event) {
  if (event.begin) {
    switch (event.type) {
      case AudioInterruptionType.pause:
        _audioPlayer.pause();
        _wasPlayingBeforeInterruption = true;
        break;
      case AudioInterruptionType.duck:
        _audioPlayer.setVolume(0.3);
        break;
      case AudioInterruptionType.unknown:
        _audioPlayer.pause();
        break;
    }
  } else {
    if (_wasPlayingBeforeInterruption) {
      _audioPlayer.play();
    }
  }
});
```

---

## 4. State Management

### Decision: Dedicated TTSCubit (Singleton)
**Rationale**: Соответствует архитектуре проекта (Bloc/Cubit), обеспечивает единственный активный плеер.

### State Model (Freezed)

```dart
@freezed
class TTSState with _$TTSState {
  const factory TTSState({
    @Default(TTSStatus.idle) TTSStatus status,
    String? currentMessageId,
    String? errorMessage,
  }) = _TTSState;
}

enum TTSStatus { idle, loading, playing, paused, error }
```

### Integration with MessageBubble

```dart
BlocBuilder<TTSCubit, TTSState>(
  builder: (context, state) {
    final isPlaying = state.currentMessageId == message.id &&
                      state.status == TTSStatus.playing;
    return TTSButton(
      isPlaying: isPlaying,
      isLoading: state.currentMessageId == message.id &&
                 state.status == TTSStatus.loading,
      onPressed: () => context.read<TTSCubit>().togglePlayback(
        messageId: message.id,
        text: message.content,
      ),
    );
  },
)
```

---

## 5. Text Preprocessing

### Decision: Server-side Markdown Stripping
**Rationale**: Сервер уже имеет доступ к тексту, проще санитизировать в одном месте.

### Processing Steps

1. Remove Markdown formatting (`**bold**` → `bold`)
2. Remove DICE tags (`[DICE: d20+2]` → "")
3. Remove emoji (опционально, ElevenLabs может их пропустить)
4. Split long text by sentence boundaries
5. Limit to 3,000 chars per chunk

---

## 6. Dependencies to Add

### Backend (pyproject.toml)

```toml
dependencies = [
    "httpx>=0.27.0",  # Already present, for async streaming
]
```

Environment variable:
```
ELEVENLABS_API_KEY=your_key_here
ELEVENLABS_VOICE_ID=voice_id_for_russian_female
```

### Flutter (pubspec.yaml)

```yaml
dependencies:
  just_audio: ^0.9.36
  audio_session: ^0.1.18
```

---

## 7. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| ElevenLabs API downtime | High | Graceful degradation, show "Озвучка недоступна" |
| Rate limit exceeded | Medium | Queue requests, show wait message |
| Long text processing | Low | Chunk text, seamless playback |
| Audio interruption bugs | Medium | Thorough testing on real device |
| Background audio rejection | Low | Follow Apple guidelines, test before submission |

---

## 8. Open Questions Resolved

| Question | Resolution |
|----------|------------|
| HTTP vs WebSocket? | HTTP streaming |
| Audio format? | MP3 44100Hz 128kbps |
| Voice selection? | Russian female, get from API |
| Chunking strategy? | 2000-3000 chars by sentence |
| State management? | Dedicated TTSCubit singleton |
