# Quickstart: ElevenLabs TTS Streaming

**Feature**: 004-elevenlabs-tts-streaming
**Date**: 2026-02-27

## Prerequisites

- Python 3.11+
- Flutter 3.x / Dart 3.x
- ElevenLabs account with API key
- Existing backend and iOS client setup

---

## 1. Backend Setup

### 1.1 Environment Variables

Add to `.env`:

```bash
ELEVENLABS_API_KEY=your_api_key_here
ELEVENLABS_VOICE_ID=your_russian_female_voice_id
ELEVENLABS_MODEL_ID=eleven_multilingual_v2
```

### 1.2 Get Russian Female Voice ID

```python
import httpx

response = httpx.get(
    "https://api.elevenlabs.io/v1/voices",
    headers={"xi-api-key": "YOUR_API_KEY"}
)
voices = response.json()["voices"]

# Find Russian female voices
russian_female = [
    v for v in voices
    if "ru" in str(v.get("labels", {})).lower()
    and v.get("labels", {}).get("gender") == "female"
]
print(russian_female)
```

### 1.3 Test Endpoint Locally

```bash
# Start backend
cd backend
uvicorn src.api.main:app --reload

# Test TTS stream (requires auth token)
curl -X POST http://localhost:8000/api/v1/tts/stream \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text": "Привет, это тест озвучки"}' \
  --output test.mp3

# Play the result
afplay test.mp3  # macOS
```

---

## 2. Flutter Setup

### 2.1 Add Dependencies

In `ios/pubspec.yaml`:

```yaml
dependencies:
  just_audio: ^0.9.36
  audio_session: ^0.1.18
```

Run:

```bash
cd ios
flutter pub get
```

### 2.2 iOS Configuration

In `ios/Runner/Info.plist`, add:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 2.3 Generate Code

```bash
cd ios
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 3. Quick Test

### 3.1 Backend Health Check

```bash
curl http://localhost:8000/api/v1/tts/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Expected: {"available": true, "message": null}
```

### 3.2 Flutter Audio Test

```dart
// Quick test in any widget
import 'package:just_audio/just_audio.dart';

final player = AudioPlayer();

// Test with any MP3 URL
await player.setUrl('https://example.com/test.mp3');
await player.play();
```

---

## 4. Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Flutter App    │     │  FastAPI        │     │  ElevenLabs     │
│                 │     │  Backend        │     │  API            │
│  ┌───────────┐  │     │                 │     │                 │
│  │ TTSCubit  │──┼────►│ POST /tts/stream│────►│ POST /stream    │
│  └───────────┘  │     │                 │     │                 │
│       │         │     │  StreamingResp  │◄────│  audio/mpeg     │
│       ▼         │◄────┼─────────────────┤     │  (chunked)      │
│  ┌───────────┐  │     │                 │     │                 │
│  │ AudioPlayer │     └─────────────────┘     └─────────────────┘
│  └───────────┘  │
└─────────────────┘
```

---

## 5. Files to Create/Modify

### Backend

| File | Action | Description |
|------|--------|-------------|
| `src/core/config.py` | Modify | Add ElevenLabs settings |
| `src/schemas/tts.py` | Create | TTSStreamRequest, TTSErrorResponse |
| `src/services/tts_service.py` | Create | ElevenLabs streaming logic |
| `src/api/routes/tts.py` | Create | TTS streaming endpoints |
| `src/api/main.py` | Modify | Register TTS router |

### Flutter

| File | Action | Description |
|------|--------|-------------|
| `pubspec.yaml` | Modify | Add just_audio, audio_session |
| `ios/Runner/Info.plist` | Modify | Add UIBackgroundModes |
| `lib/features/game_session/bloc/tts_cubit.dart` | Create | TTS state management |
| `lib/features/game_session/bloc/tts_state.dart` | Create | TTSState freezed model |
| `lib/features/game_session/data/tts_api.dart` | Create | TTS API client |
| `lib/features/game_session/ui/widgets/tts_button.dart` | Create | Play/Stop button widget |
| `lib/features/game_session/ui/widgets/message_bubble.dart` | Modify | Add TTS button to DM messages |
| `lib/core/di/injection.dart` | Modify | Register TTSCubit |

---

## 6. Key Code Snippets

### Backend: Streaming Response

```python
from fastapi.responses import StreamingResponse

async def stream_elevenlabs_audio(text: str) -> StreamingResponse:
    async def generate():
        async with httpx.AsyncClient() as client:
            async with client.stream(
                "POST",
                f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream",
                json={"text": text, "model_id": "eleven_multilingual_v2"},
                headers={"xi-api-key": settings.elevenlabs_api_key}
            ) as response:
                async for chunk in response.aiter_bytes(4096):
                    yield chunk

    return StreamingResponse(generate(), media_type="audio/mpeg")
```

### Flutter: Play Streaming Audio

```dart
final player = AudioPlayer();

Future<void> playTTS(String text) async {
  final url = '${apiBaseUrl}/tts/stream';

  // just_audio handles streaming internally
  await player.setUrl(url, headers: {'Authorization': 'Bearer $token'});
  await player.play();
}
```

---

## 7. Testing Checklist

- [ ] Backend streams audio without errors
- [ ] Flutter plays streamed audio
- [ ] Stop button stops playback immediately
- [ ] Phone call pauses and resumes audio
- [ ] Background playback works
- [ ] Long text is chunked correctly
- [ ] Rate limit error shows user-friendly message
- [ ] Only one message plays at a time
