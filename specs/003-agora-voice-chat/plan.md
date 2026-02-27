# Implementation Plan: Голосовой чат в игровых комнатах

**Branch**: `003-agora-voice-chat` | **Date**: 2026-02-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-agora-voice-chat/spec.md`

## Summary

Добавить голосовой чат реального времени в активные игровые комнаты с использованием Agora RTC SDK.
Бэкенд (FastAPI) выдаёт временные токены доступа к голосовым каналам Agora; Flutter-клиент управляет подключением,
отображением активности говорящих и передаёт команды mute через существующий WebSocket-канал игровой сессии.

## Technical Context

**Language/Version**: Python 3.11+ (backend), Dart 3.x / Flutter 3.x (iOS client)
**Primary Dependencies**: FastAPI + `agora-token>=2.0.0` (backend); `agora_rtc_engine ^6.3.0` + flutter_bloc (Flutter)
**Storage**: PostgreSQL (существующий, без новых таблиц) + Agora инфраструктура (медиа)
**Testing**: pytest + pytest-asyncio (backend), Flutter widget tests (iOS)
**Target Platform**: iOS 12+ (клиент), Linux server (backend)
**Project Type**: Mobile app + REST API (добавление фичи к существующему проекту)
**Performance Goals**: Аудио задержка <300мс; подключение к каналу <3 сек; индикатор говорящего <500мс
**Constraints**: Бесплатный план Agora ≤10 000 мин/месяц; токен живёт 4 часа; макс. 6 участников
**Scale/Scope**: До 6 одновременных участников на канал; N активных комнат одновременно

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Принцип | Статус | Комментарий |
|---------|--------|-------------|
| I. AI только на бэкенде | ✅ PASS | Agora не AI — исключение не требуется. Все AI-вызовы по-прежнему на бэкенде |
| II. Мультиплеер реального времени (WebSocket) | ✅ PASS | Agora для медиа; команды mute/close идут через существующий WebSocket |
| III. Безопасность контента | ✅ PASS | Голос не фильтруется AI, но Политика конфиденциальности должна упоминать голосовые данные (уже в конституции) |
| IV. Оптимизация затрат | ✅ PASS | Agora бесплатный план покрывает ~100 сессий/мес; нет лишних AI-вызовов |
| V. TDD | ✅ PASS | Unit-тесты для генерации токена обязательны; интеграционные тесты для WebSocket-сообщений |
| VI. D&D 5e | ✅ N/A | Голосовой чат не затрагивает игровую механику |
| App Store: NSMicrophoneUsageDescription | ✅ PASS | Добавляется в Info.plist |
| App Store: UIBackgroundModes | ✅ PASS | audio + voip добавляются в Info.plist |

**Вывод**: Все принципы соблюдены. Нарушений нет.

## Project Structure

### Documentation (this feature)

```text
specs/003-agora-voice-chat/
├── plan.md              # This file
├── research.md          # Phase 0 ✅
├── data-model.md        # Phase 1 ✅
├── quickstart.md        # Phase 1 ✅
├── contracts/
│   └── voice-api.yaml   # Phase 1 ✅
└── tasks.md             # Phase 2 (создаётся командой /speckit.tasks)
```

### Source Code (repository root)

```text
backend/
├── src/
│   ├── core/
│   │   └── config.py          # + AGORA_APP_ID, AGORA_APP_CERTIFICATE, AGORA_TOKEN_EXPIRE_SECONDS
│   ├── schemas/
│   │   ├── websocket.py       # + VOICE_MUTE_USER, VOICE_CHANNEL_CLOSED типы
│   │   └── voice.py           # NEW: VoiceTokenResponse, VoiceMuteRequest
│   ├── services/
│   │   └── voice_service.py   # NEW: generate_token(), mute_participant()
│   └── api/
│       ├── routes/
│       │   ├── voice.py        # NEW: GET /rooms/{id}/voice-token, POST /rooms/{id}/voice/mute/{uid}
│       │   ├── websocket.py   # MODIFY: отправлять VOICE_CHANNEL_CLOSED при end-session
│       │   └── sessions.py    # MODIFY: вызывать voice_service при завершении сессии
│       └── main.py            # MODIFY: подключить voice_router
└── tests/
    └── unit/
        └── test_voice_service.py  # NEW: тесты генерации токенов

ios/
├── lib/
│   └── features/
│       └── game_session/
│           ├── models/
│           │   └── voice_models.dart         # NEW: VoiceToken, VoiceParticipant, freezed
│           ├── bloc/
│           │   └── voice_cubit.dart          # NEW: VoiceCubit + VoiceState
│           ├── data/
│           │   └── game_session_repository.dart  # MODIFY: + getVoiceToken(), muteParticipant()
│           ├── pages/
│           │   └── game_session_page.dart    # MODIFY: + BlocProvider<VoiceCubit>, голосовые виджеты
│           └── widgets/
│               ├── voice_controls_widget.dart     # NEW: кнопки подключения/mute
│               └── voice_participant_indicator.dart  # NEW: индикатор говорящего
└── Runner/
    └── Info.plist  # MODIFY: NSMicrophoneUsageDescription, UIBackgroundModes
```

**Structure Decision**: Архитектура Mobile + API (Option 3). Голосовая фича интегрируется в существующий
`game_session` feature-модуль (iOS) и добавляет новый voice-роут + сервис на бэкенде.
Новых верхнеуровневых модулей не создаётся — соответствие принципу минимальной сложности.

## Complexity Tracking

> Нарушений конституции нет — раздел не применяется.
