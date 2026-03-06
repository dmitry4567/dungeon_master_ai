# Data Model: Голосовой чат в игровых комнатах

**Feature**: 003-agora-voice-chat
**Date**: 2026-02-27

---

## Обзор

Голосовой чат не требует новых таблиц в БД. Всё состояние — эфемерное (в памяти клиента и сервисах Agora).
Единственное изменение на бэкенде: добавить конфигурацию Agora в `Settings` и новый endpoint для выдачи токенов.

---

## Backend: Изменения в Settings

```python
# backend/src/core/config.py — добавить поля:
agora_app_id: str = Field(default="", alias="AGORA_APP_ID")
agora_app_certificate: str = Field(default="", alias="AGORA_APP_CERTIFICATE")
agora_token_expire_seconds: int = Field(default=14400, alias="AGORA_TOKEN_EXPIRE_SECONDS")
```

---

## Backend: Response Schema

```python
# backend/src/schemas/voice.py (новый файл)

class VoiceTokenResponse(BaseModel):
    token: str           # Agora RTC token
    channel_name: str    # = room_id (строка UUID)
    uid: int             # числовой uid пользователя для Agora
    app_id: str          # Agora App ID (нужен клиенту для инициализации SDK)
    expires_at: datetime # UTC время истечения токена
```

---

## Flutter: Модели

```dart
// ios/lib/features/game_session/models/voice_models.dart

@freezed
class VoiceToken with _$VoiceToken {
  const factory VoiceToken({
    required String token,
    required String channelName,
    required int uid,
    required String appId,
    required DateTime expiresAt,
  }) = _VoiceToken;

  factory VoiceToken.fromJson(Map<String, dynamic> json) =>
      _$VoiceTokenFromJson(json);
}

@freezed
class VoiceParticipant with _$VoiceParticipant {
  const factory VoiceParticipant({
    required int uid,              // Agora uid
    required String userId,        // UUID пользователя
    required String displayName,
    @Default(false) bool isSpeaking,
    @Default(false) bool isMuted,
    @Default(false) bool isConnected,
  }) = _VoiceParticipant;
}

enum VoiceConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}
```

---

## Flutter: VoiceCubit State

```dart
// ios/lib/features/game_session/bloc/voice_cubit.dart

@freezed
class VoiceState with _$VoiceState {
  const factory VoiceState({
    @Default(VoiceConnectionStatus.disconnected)
    VoiceConnectionStatus connectionStatus,

    @Default(false) bool isMuted,
    @Default({}) Map<int, VoiceParticipant> participants, // uid → participant

    VoiceToken? token,
    String? errorMessage,
  }) = _VoiceState;
}
```

---

## WebSocket: Новые типы сообщений

Добавляются к существующим типам в `backend/src/schemas/websocket.py`:

| Тип сообщения | Направление | Назначение |
|---------------|-------------|-----------|
| `VOICE_CHANNEL_CLOSED` | Server → Client | Сессия завершена, закрыть голосовой канал |

```python
# Структура VOICE_CHANNEL_CLOSED
{
    "type": "VOICE_CHANNEL_CLOSED",
    "data": {}
}
```

---

## Связи с существующими моделями

```
Room (existing)
  └── id (UUID) → используется как channel_name в Agora
  └── players (RoomPlayer[]) → каждый получает VoiceToken по запросу

GameSession (existing)
  └── room_id → при end_session рассылается VOICE_CHANNEL_CLOSED

User (existing)
  └── id (UUID) → uid = abs(hash(str(id))) % (2**31)
```

---

## Жизненный цикл голосового канала

```
Room.status = WAITING
  └── Голосовой канал недоступен

Room.status = ACTIVE (игровая сессия начата)
  └── Игрок запрашивает токен: GET /rooms/{room_id}/voice-token
  └── Клиент подключается к Agora каналу
  └── Голосовой чат активен

POST /sessions/{session_id}/end (хост завершает игру)
  └── Бэкенд рассылает VOICE_CHANNEL_CLOSED через WebSocket
  └── Клиент вызывает engine.leaveChannel()
  └── Голосовой канал закрыт
```
