# Quickstart: Голосовой чат (Agora RTC)

**Feature**: 003-agora-voice-chat
**Date**: 2026-02-27

---

## Предварительные условия

1. Аккаунт на [agora.io](https://console.agora.io) с созданным проектом
2. Получить **App ID** и **App Certificate** из консоли Agora

---

## Backend Setup

### 1. Установить зависимость

```bash
cd backend
pip install agora-token
```

Добавить в `pyproject.toml`:
```toml
"agora-token>=2.0.0",
```

### 2. Добавить переменные окружения

В файл `backend/.env`:
```env
AGORA_APP_ID=ваш_app_id_из_консоли_agora
AGORA_APP_CERTIFICATE=ваш_app_certificate_из_консоли_agora
AGORA_TOKEN_EXPIRE_SECONDS=14400
```

### 3. Обновить конфигурацию

В `backend/src/core/config.py` добавить поля (см. `data-model.md`).

### 4. Создать сервис и маршруты

Создать файлы:
- `backend/src/services/voice_service.py` — генерация токенов, логика mute
- `backend/src/api/routes/voice.py` — REST endpoints
- `backend/src/schemas/voice.py` — Pydantic схемы

Подключить router в `backend/src/api/main.py`:
```python
from src.api.routes.voice import router as voice_router
app.include_router(voice_router, prefix="/api/v1", tags=["voice"])
```

### 5. Добавить WebSocket типы сообщений

В `backend/src/schemas/websocket.py` добавить:
```python
VOICE_MUTE_USER = "VOICE_MUTE_USER"
VOICE_CHANNEL_CLOSED = "VOICE_CHANNEL_CLOSED"
```

В `backend/src/api/routes/websocket.py` обработать `VOICE_CHANNEL_CLOSED` при вызове end-session.

---

## Flutter Setup

### 1. Добавить зависимость

В `ios/pubspec.yaml`:
```yaml
dependencies:
  agora_rtc_engine: ^6.3.0
  permission_handler: ^11.0.0  # если ещё не добавлен
```

```bash
cd ios
flutter pub get
```

### 2. Настроить Info.plist

В `ios/Runner/Info.plist` добавить (если ещё не добавлено):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for voice chat during gameplay</string>

<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>voip</string>
</array>
```

### 3. Создать модели

Создать `ios/lib/features/game_session/models/voice_models.dart` (см. `data-model.md`).

Запустить генерацию кода:
```bash
cd ios
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Создать VoiceCubit

Создать `ios/lib/features/game_session/bloc/voice_cubit.dart` с методами:
- `connect(roomId)` → запросить токен, инициализировать SDK, войти в канал
- `disconnect()` → покинуть канал, освободить ресурсы
- `toggleMute()` → включить/выключить микрофон
- `muteParticipant(uid)` → только для хоста

### 5. Создать API-клиент

Добавить в `ios/lib/features/game_session/data/game_session_repository.dart`:
```dart
Future<VoiceToken> getVoiceToken(String roomId);
Future<void> muteParticipant(String roomId, String targetUserId);
```

### 6. Интегрировать в GameSessionPage

В `ios/lib/features/game_session/pages/game_session_page.dart`:
- Добавить `BlocProvider<VoiceCubit>`
- Добавить `VoiceControlsWidget` в нижнюю панель экрана
- Обработать WebSocket-сообщения `VOICE_MUTE_USER` и `VOICE_CHANNEL_CLOSED` в существующем `GameSessionBloc`

### 7. Создать UI-виджеты

- `VoiceControlsWidget` — кнопки подключения, mute, список участников
- `VoiceParticipantIndicator` — индикатор говорящего рядом с именем игрока

---

## Проверка работоспособности

### Backend
```bash
cd backend
uvicorn src.api.main:app --reload

# Запросить токен (нужен JWT токен авторизованного игрока активной комнаты):
curl -H "Authorization: Bearer <jwt>" \
  http://localhost:8000/api/v1/rooms/<room_id>/voice-token
```

Ожидаемый ответ:
```json
{
  "token": "006abc...",
  "channel_name": "550e8400-...",
  "uid": 1234567890,
  "app_id": "abcdef...",
  "expires_at": "2026-02-27T17:00:00Z"
}
```

### Flutter
1. Запустить симулятор iOS (или устройство)
2. Открыть активную игровую сессию
3. Нажать кнопку микрофона → должен появиться запрос разрешений
4. Разрешить доступ к микрофону → подключение к голосовому каналу
5. Второй участник аналогично подключается — они должны слышать друг друга

---

## Стоимость Agora

- До **10 000 минут/месяц бесплатно** для голосовых каналов
- Далее ~$1.49/1000 минут (аудио)
- При 6 игроках × 2 часа = 720 минут на сессию → ~100 сессий в рамках бесплатного плана
