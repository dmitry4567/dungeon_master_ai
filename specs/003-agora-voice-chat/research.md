# Research: Голосовой чат в игровых комнатах (Agora RTC)

**Feature**: 003-agora-voice-chat
**Date**: 2026-02-27

---

## 1. Flutter SDK: agora_rtc_engine

### Decision
Использовать пакет `agora_rtc_engine ^6.x` (последняя стабильная серия).

### Rationale
- Официальный SDK от Agora для Flutter
- Поддерживает iOS 12+
- Встроенная обработка разрешений, автоматическое переподключение
- Активная поддержка, регулярные обновления

### Key API

```dart
// Инициализация
final engine = createAgoraRtcEngine();
await engine.initialize(RtcEngineContext(appId: appId));
await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
await engine.enableAudio();

// Регистрация обработчиков событий
engine.registerEventHandler(RtcEngineEventHandler(
  onJoinChannelSuccess: (connection, elapsed) { ... },
  onUserOffline: (connection, remoteUid, reason) { ... },
  onActiveSpeaker: (connection, uid) { ... },       // говорящий
  onAudioVolumeIndication: (connection, speakers, totalVolume) { ... },
));

// Включить индикацию активности говорящего (каждые 200мс)
await engine.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);

// Подключение к каналу
await engine.joinChannel(
  token: token,
  channelId: channelName,
  uid: uid,            // числовой uid (можно хэш от UUID)
  options: const ChannelMediaOptions(
    channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    clientRoleType: ClientRoleType.clientRoleBroadcaster,
  ),
);

// Заглушить/включить свой микрофон
await engine.muteLocalAudioStream(mute: true);
await engine.muteLocalAudioStream(mute: false);

// Заглушить удалённого участника (хост)
await engine.muteRemoteAudioStream(uid: remoteUid, mute: true);

// Выйти из канала
await engine.leaveChannel();
await engine.release();
```

### Permissions (iOS Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for voice chat during gameplay</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is required for voice communication.</string>
```
Конституция уже требует `NSMicrophoneUsageDescription` — соответствие выполнено.

### Background audio (iOS)
Добавить в `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>voip</string>
</array>
```

### Podfile (ios/Podfile)
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_MICROPHONE=1',
      ]
    end
  end
end
```

### Network Reconnection
Agora SDK автоматически переподключается при потере сети. События:
- `onConnectionStateChanged(state: ConnectionStateReconnecting)` — начало переподключения
- `onConnectionStateChanged(state: ConnectionStateConnected)` — восстановлено

---

## 2. Token Generation: Python Backend

### Decision
Использовать библиотеку `agora-token` (PyPI: `agora-token>=2.0.0`) для генерации RTC-токенов на бэкенде.

### Rationale
- Официальная библиотека от Agora
- Простая интеграция с FastAPI
- Токены генерируются локально без внешних HTTP-вызовов (нет задержки)

### Token Parameters
| Параметр | Тип | Описание |
|----------|-----|---------|
| app_id | str | Agora App ID (из консоли) |
| app_certificate | str | Agora App Certificate (секрет) |
| channel_name | str | Идентификатор канала = room_id |
| uid | int | Числовой uid пользователя |
| role | int | 1 = Publisher (говорит), 2 = Subscriber (только слушает) |
| privilege_expire_ts | int | Unix timestamp истечения (токен + привилегии) |

### Token Expiry Strategy
- Токен выдаётся на **4 часа** (14400 секунд) — покрывает типичную игровую сессию 2-3 часа
- Клиент обязан запросить новый токен через `onTokenPrivilegeWillExpire` (за 30 сек до истечения)
- Бэкенд предоставляет endpoint `/rooms/{room_id}/voice-token` для обновления

### Python Code Example
```python
from agora_token_builder import RtcTokenBuilder, Role_Publisher

def generate_voice_token(
    app_id: str,
    app_certificate: str,
    channel_name: str,
    uid: int,
    expire_seconds: int = 14400,
) -> str:
    expire_ts = int(time.time()) + expire_seconds
    return RtcTokenBuilder.buildTokenWithUid(
        app_id, app_certificate, channel_name, uid,
        Role_Publisher, expire_ts
    )
```

### Environment Variables (добавить в Settings)
```
AGORA_APP_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AGORA_APP_CERTIFICATE=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### UID Mapping
UUID пользователя → числовой uid для Agora:
```python
uid = abs(hash(str(user_id))) % (2**31)  # детерминированно, без коллизий при 6 участниках
```

---

## 3. Channel Naming Strategy

### Decision
Имя канала Agora = `room_id` (UUID комнаты как строка).

### Rationale
- Уникально в рамках всей системы
- Не требует дополнительного хранения
- Совпадает с идентификатором WebSocket-сессии — единая точка истины

---

## 4. Host Muting Architecture

### Decision
Принудительное заглушение хостом реализовано через **WebSocket-сообщение** + локальный mute на клиенте.

### Rationale
Agora не имеет серверного API для принудительного заглушения в реальном времени в базовых тарифах.
Альтернатива: хост отправляет через существующий WebSocket-канал сообщение типа `VOICE_MUTE_USER`,
клиент получает его и вызывает `muteLocalAudioStream(true)`.

### Flow
```
Host (Flutter) → POST /rooms/{id}/voice/mute/{uid}
Backend → WebSocket broadcast: { type: "VOICE_MUTE_USER", uid: target_uid }
Target client → engine.muteLocalAudioStream(mute: true)
```

---

## 5. Session End / Cleanup

### Decision
При вызове `POST /sessions/{id}/end` бэкенд рассылает WebSocket-сообщение `VOICE_CHANNEL_CLOSED`.
Клиент получает его и вызывает `engine.leaveChannel()`.

---

## 6. Flutter Architecture (BLoC)

### Decision
Создать `VoiceCubit` в `ios/lib/features/game_session/` (не новый feature-модуль — голос привязан к игровой сессии).

### State
```dart
class VoiceState {
  final bool isConnected;
  final bool isMuted;
  final bool isMutedByHost;
  final Map<int, VoiceParticipant> participants; // uid -> participant
}
```

### Integration
`VoiceCubit` живёт внутри `GameSessionPage` рядом с `GameSessionBloc`. Оба используют один и тот же `room_id`.

---

## 7. Resolved Clarifications

| # | Вопрос | Решение |
|---|--------|---------|
| 1 | Как хранить статус голосового канала? | Только в памяти клиента + Agora инфраструктура. БД не нужна. |
| 2 | Принудительное заглушение через Agora или WebSocket? | Через существующий WebSocket канал игровой сессии. |
| 3 | Числовой uid для Agora из UUID? | `abs(hash(str(user_id))) % (2**31)` — детерминированный хэш |
| 4 | Токен: где хранить на клиенте? | В памяти (VoiceCubit state), не персистировать |
| 5 | Background audio? | Да, через `UIBackgroundModes: audio + voip` в Info.plist |
