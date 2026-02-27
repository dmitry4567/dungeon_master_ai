# Tasks: Голосовой чат в игровых комнатах (Agora RTC)

**Input**: Design documents from `/specs/003-agora-voice-chat/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Organization**: Задачи сгруппированы по пользовательским историям из spec.md для независимой реализации и тестирования.

**Изменения от 2026-02-27**: Удалена Phase 6 (US3 — принудительное заглушение хостом) — исключено из scope по результатам clarification.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Можно выполнять параллельно (разные файлы, нет зависимостей)
- **[Story]**: Пользовательская история (US1–US3; US3 = автоотключение, бывшая US4 в spec до clarification)

---

## Phase 1: Setup (Настройка)

**Purpose**: Установка зависимостей и подготовка окружения

- [x] T001 Добавить `agora-token>=2.0.0` в `backend/pyproject.toml` в секцию `dependencies`
- [x] T002 [P] Добавить `agora_rtc_engine: ^6.3.0` в `ios/pubspec.yaml` в секцию `dependencies`
- [x] T003 [P] Добавить `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, `AGORA_TOKEN_EXPIRE_SECONDS=14400` в `backend/.env` и `backend/.env.example`
- [x] T004 Добавить `NSMicrophoneUsageDescription`, `NSLocalNetworkUsageDescription` и `UIBackgroundModes: [audio, voip]` в `ios/Runner/Info.plist`; добавить `PERMISSION_MICROPHONE=1` в `ios/Podfile`

---

## Phase 2: Foundational (Блокирующие Prerequisites)

**Purpose**: Базовая инфраструктура, которая нужна всем пользовательским историям

**⚠️ CRITICAL**: Пользовательские истории не могут начаться до завершения этой фазы

- [x] T005 Добавить поля `agora_app_id: str`, `agora_app_certificate: str`, `agora_token_expire_seconds: int = 14400` в класс `Settings` в `backend/src/core/config.py`
- [x] T006 [P] Создать `backend/src/schemas/voice.py` с Pydantic-моделью `VoiceTokenResponse` (token, channel_name, uid, app_id, expires_at) согласно `data-model.md`
- [x] T007 [P] Добавить константу `VOICE_CHANNEL_CLOSED = "VOICE_CHANNEL_CLOSED"` в `backend/src/schemas/websocket.py`
- [x] T008 Создать `backend/src/services/voice_service.py` с функциями `generate_voice_token(app_id, app_certificate, channel_name, uid, expire_seconds)` и `get_agora_uid(user_id)` согласно `research.md` (uid = abs(hash(str(user_id))) % (2**31))
- [x] T009 Создать `backend/tests/unit/test_voice_service.py` с unit-тестами для `generate_voice_token` (корректные параметры, истечение токена) и `get_agora_uid` (детерминированность, диапазон значений)
- [x] T010 Создать `ios/lib/features/game_session/models/voice_models.dart` с freezed-моделями `VoiceToken`, `VoiceParticipant` (без поля `isMutedByHost`) и enum `VoiceConnectionStatus` согласно `data-model.md`
- [x] T011 Запустить `flutter pub get` и `flutter pub run build_runner build --delete-conflicting-outputs` в директории `ios/` для генерации `.g.dart` и `.freezed.dart` файлов

**Checkpoint**: Foundation ready — пользовательские истории можно реализовывать

---

## Phase 3: User Story 1 — Подключение к голосовому каналу (Priority: P1) 🎯 MVP

**Goal**: Игрок может подключиться к голосовому каналу активной комнаты, слышать других, включать/выключать микрофон и отключаться.

**Independent Test**: Два игрока в одной активной комнате нажимают "Подключиться к голосу" → слышат друг друга. Нажатие "Заглушить" прекращает передачу голоса. Нажатие "Отключиться" разрывает канал.

### Backend

- [x] T012 [US1] Создать `backend/src/api/routes/voice.py` с endpoint `GET /rooms/{room_id}/voice-token`: проверить что пользователь — участник комнаты, что статус комнаты `ACTIVE`, вызвать `voice_service.generate_voice_token()`, вернуть `VoiceTokenResponse`; вернуть 503 если `AGORA_APP_ID` не настроен
- [x] T013 [US1] Зарегистрировать voice router в `backend/src/api/main.py`: `app.include_router(voice_router, prefix="/api/v1", tags=["voice"])`

### Flutter: VoiceCubit

- [x] T014 [US1] Создать `ios/lib/features/game_session/bloc/voice_cubit.dart` с `VoiceState` (connectionStatus, isMuted, participants, token, errorMessage) и методами `connect(roomId)`, `disconnect()`, `toggleMute()`
- [x] T015 [US1] Реализовать `connect(roomId)` в `VoiceCubit`: запросить токен через repository, инициализировать `RtcEngine` с `channelProfileLiveBroadcasting`, вызвать `enableAudio()`, `enableAudioVolumeIndication(interval: 200)`, зарегистрировать `RtcEngineEventHandler`, вызвать `joinChannel()`
- [x] T016 [US1] Реализовать `disconnect()` в `VoiceCubit`: вызвать `engine.leaveChannel()`, `engine.release()`, обнулить состояние
- [x] T017 [US1] Реализовать `toggleMute()` в `VoiceCubit`: вызвать `engine.muteLocalAudioStream(mute: !state.isMuted)`, обновить `isMuted` в состоянии

### Flutter: Repository и API

- [x] T018 [US1] Добавить метод `getVoiceToken(String roomId) → Future<VoiceToken>` в `ios/lib/features/game_session/data/game_session_repository.dart`

### Flutter: UI

- [x] T019 [P] [US1] Создать `ios/lib/features/game_session/widgets/voice_controls_widget.dart` с кнопками "Подключиться к голосу" / "Отключиться" и иконкой микрофона с toggled-состоянием; кнопка недоступна если комната не в статусе `ACTIVE`
- [x] T020 [US1] Добавить `BlocProvider<VoiceCubit>` и `VoiceControlsWidget` в нижнюю панель `ios/lib/features/game_session/pages/game_session_page.dart`

**Checkpoint**: User Story 1 полностью функциональна — игроки слышат друг друга в активной комнате

---

## Phase 4: User Story 2 — Визуальная индикация говорящего (Priority: P2)

**Goal**: Рядом с именем/аватаром говорящего игрока появляется анимированный индикатор активности в реальном времени.

**Independent Test**: Когда один игрок говорит, у остальных участников рядом с его именем появляется анимированный индикатор; при замолкании исчезает за ≤1 сек.

### Flutter: Cubit (расширение)

- [x] T021 [US2] Добавить обработчик `onAudioVolumeIndication`; порог активной речи: `volume > 30` (диапазон Agora 0–255) в `RtcEngineEventHandler` в `voice_cubit.dart`: обновлять `participants[uid].isSpeaking` на основе `speakers` и пороговых значений громкости
- [x] T022 [US2] Добавить обработчик `onActiveSpeaker` в `RtcEngineEventHandler` в `voice_cubit.dart` как резервный источник данных об активном говорящем
- [x] T023 [US2] Добавить обработчики `onUserJoined` и `onUserOffline` в `RtcEngineEventHandler` в `voice_cubit.dart` для отслеживания `participants` map

### Flutter: UI

- [x] T024 [P] [US2] Создать `ios/lib/features/game_session/widgets/voice_participant_indicator.dart` — AnimatedWidget с пульсирующей рамкой/иконкой, принимает `isSpeaking: bool`
- [x] T025 [US2] Интегрировать `VoiceParticipantIndicator` в виджет списка игроков в `ios/lib/features/game_session/widgets/` (найти существующий PlayerList/PlayerCard виджет через поиск по кодовой базе): показывать индикатор рядом с именем когда `participants[uid]?.isSpeaking == true`
- [x] T026 [US2] Показывать иконку "заглушен" рядом с именем участника в `VoiceControlsWidget` когда `participants[uid]?.isMuted == true`

**Checkpoint**: User Stories 1 и 2 работают — игроки слышат друг друга и видят кто говорит

---

## Phase 5: User Story 3 — Автоматическое отключение при завершении сессии (Priority: P2)

**Goal**: При завершении игровой сессии все участники автоматически отключаются от голосового канала. Выход хоста без явного завершения канал не закрывает.

**Independent Test**: Хост нажимает "Завершить игру" → все участники автоматически отключаются от голосового канала без ручных действий.

### Backend

- [ ] T027 [US3] Добавить рассылку `VOICE_CHANNEL_CLOSED` через `connection_manager.broadcast_to_room()` в `backend/src/api/routes/sessions.py` в endpoint `POST /sessions/{session_id}/end` (после обновления статуса сессии)

### Flutter

- [ ] T028 [US3] Добавить обработку сообщения `VOICE_CHANNEL_CLOSED` в `GameSessionBloc` в `ios/lib/features/game_session/bloc/game_session_bloc.dart`: при получении вызывать `voiceCubit.disconnect()`
- [ ] T029 [US3] Добавить обработчик `onConnectionStateChanged` в `RtcEngineEventHandler` в `voice_cubit.dart`: при `ConnectionStateReconnecting` — `VoiceConnectionStatus.reconnecting`, при `ConnectionStateConnected` — `connected`
- [ ] T030 [US3] Убедиться что `VoiceCubit.disconnect()` вызывается в `dispose()` при выходе из `GameSessionPage` в `game_session_page.dart`

**Checkpoint**: Все 3 пользовательские истории реализованы

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Обработка ошибок и edge cases

- [ ] T031 Добавить запрос разрешения на микрофон через `permission_handler` в `voice_cubit.dart` перед первым вызовом `connect()`: если отклонено — показать диалог с объяснением и кнопкой "Открыть Настройки" (`openAppSettings()`)
- [ ] T032 [P] Добавить обработку ошибки подключения к Agora в `voice_cubit.dart`: при неудаче установить `connectionStatus: VoiceConnectionStatus.error` и `errorMessage`; показать в `VoiceControlsWidget` сообщение об ошибке с кнопкой "Повторить" — текстовая сессия продолжается
- [ ] T033 [P] Добавить обработку ошибок в `backend/src/api/routes/voice.py`: 409 если комната не `ACTIVE`, 503 если `AGORA_APP_ID` не настроен, 403 если пользователь не участник комнаты
- [ ] T034 [P] Добавить логирование `structlog` в `backend/src/services/voice_service.py` для событий: `token_generated` (user_id, room_id, expires_at)
- [ ] T035 Проверить корректную инициализацию и освобождение `RtcEngine` при повторном входе/выходе из `GameSessionPage` (`dispose()` в `voice_cubit.dart`)
- [ ] T036 [P] Убедиться что `backend/tests/unit/test_voice_service.py` проходят: `pytest backend/tests/unit/test_voice_service.py -v`
- [ ] T037 [US3] Добавить обработчик `onTokenPrivilegeWillExpire` в `RtcEngineEventHandler` в `voice_cubit.dart`: запросить новый токен через `repository.getVoiceToken(roomId)` и вызвать `engine.renewToken(newToken)` без разрыва соединения (FR-008 / автоматическое переподключение)

---

## Dependencies

```
Phase 1 (Setup)
  └── Phase 2 (Foundation)
        ├── Phase 3 (US1 - MVP) 🎯
        │     └── Phase 4 (US2) — зависит от VoiceCubit из US1
        │           └── Phase 5 (US3) — зависит от VoiceCubit + GameSessionBloc из US1/US2
        └── Phase 6 (Polish) — можно начать после Phase 3
```

### Параллельные возможности

**В Phase 1**: T002 (Flutter pubspec) и T003 (env vars) параллельно с T001
**В Phase 2**: T006 (schemas) + T007 (WS constants) + T010 (Flutter models) параллельно после T005
**В Phase 3**: T019 (VoiceControlsWidget UI) параллельно с T014–T018 (Cubit + backend)
**В Phase 6**: T032, T033, T034, T036 параллельно

---

## Implementation Strategy

### MVP (Phase 1 + 2 + 3)
Задачи T001–T020: игроки слышат друг друга и могут управлять своим микрофоном.

### Increment 2 (+ Phase 4)
Задачи T021–T026: визуальные индикаторы говорящих.

### Full Feature (+ Phase 5 + 6)
Задачи T027–T036: автозакрытие канала при завершении сессии + polish.

---

## Summary

| Метрика | Значение |
|---------|----------|
| Всего задач | 37 |
| Phase 1 (Setup) | 4 |
| Phase 2 (Foundation) | 7 |
| US1 — Подключение (P1) 🎯 | 9 |
| US2 — Индикация говорящего (P2) | 6 |
| US3 — Авто-отключение (P2) | 4 |
| Polish | 6 |
| Параллельных задач [P] | 11 |
| MVP scope | T001–T020 (Phase 1+2+3) |
| Исключено из scope | Принудительное заглушение хостом |
