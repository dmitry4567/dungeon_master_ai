# Tasks: iOS-клиент AI Dungeon Master

**Input**: Design documents from `/specs/001-ios-client/`
**Prerequisites**: plan.md, spec.md, data-model.md, research.md, quickstart.md

**Tests**: Включены согласно конституции (V. Разработка через тестирование): bloc_test, widget-тесты, интеграционные тесты

**Organization**: Задачи сгруппированы по пользовательским историям для независимой реализации

## Формат: `[ID] [P?] [Story] Description`

- **[P]**: Можно выполнять параллельно (разные файлы, нет зависимостей)
- **[Story]**: К какой пользовательской истории относится (US1-US6)
- Включены точные пути к файлам

---

## Phase 1: Setup (Инициализация проекта)

**Purpose**: Создание Flutter-проекта и базовой структуры

- [ ] T001 Создать Flutter-проект в ios/ с именем ai_dungeon_master
- [ ] T002 Настроить pubspec.yaml с зависимостями: flutter_bloc, get_it, injectable, freezed, go_router, dio, retrofit, web_socket_channel, flutter_tts, speech_to_text, isar, flutter_secure_storage, firebase_core, firebase_crashlytics, firebase_analytics
- [ ] T003 [P] Настроить analysis_options.yaml с правилами линтинга
- [ ] T004 [P] Настроить build.yaml для freezed и injectable
- [ ] T005 [P] Создать структуру директорий согласно plan.md: lib/core/, lib/features/, lib/shared/
- [ ] T006 [P] Настроить ios/Runner/Info.plist с разрешениями: NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
- [ ] T007 [P] Создать .env.example с переменными окружения (API_BASE_URL)

---

## Phase 2: Foundational (Базовая инфраструктура)

**Purpose**: Инфраструктура, БЛОКИРУЮЩАЯ все пользовательские истории

- [ ] T008 Реализовать конфигурацию приложения в ios/lib/core/config/app_config.dart
- [ ] T009 [P] Настроить get_it + injectable DI в ios/lib/core/di/injection.dart
- [ ] T010 [P] Создать базовую тему приложения в ios/lib/core/theme/app_theme.dart
- [ ] T011 [P] Создать цветовую палитру (фэнтези-стиль) в ios/lib/core/theme/colors.dart
- [ ] T012 [P] Создать типографику с Dynamic Type в ios/lib/core/theme/typography.dart
- [ ] T013 Реализовать Dio API-клиент с интерсепторами в ios/lib/core/network/api_client.dart
- [ ] T014 [P] Реализовать auth-интерсептор (JWT) в ios/lib/core/network/interceptors/auth_interceptor.dart
- [ ] T015 [P] Реализовать error-интерсептор в ios/lib/core/network/interceptors/error_interceptor.dart
- [ ] T016 Реализовать WebSocket-клиент в ios/lib/core/network/websocket_client.dart
- [ ] T017 Реализовать secure storage для токенов в ios/lib/core/storage/secure_storage.dart
- [ ] T018 Настроить Isar базу данных в ios/lib/core/storage/local_database.dart
- [ ] T019 Настроить go_router в ios/lib/core/router/app_router.dart
- [ ] T020 [P] Создать константы маршрутов в ios/lib/core/router/routes.dart
- [ ] T021 Создать точку входа приложения в ios/lib/main.dart
- [ ] T022 Создать MaterialApp с роутером в ios/lib/app.dart
- [ ] T023 [P] Создать общие виджеты: LoadingSkeleton в ios/lib/shared/widgets/loading_skeleton.dart
- [ ] T024 [P] Создать общие виджеты: ErrorView в ios/lib/shared/widgets/error_view.dart
- [ ] T025 [P] Создать общие виджеты: OfflineBanner в ios/lib/shared/widgets/offline_banner.dart
- [ ] T026 [P] Создать общие виджеты: FantasyButton в ios/lib/shared/widgets/fantasy_button.dart
- [ ] T027 Настроить Firebase (Crashlytics, Analytics) в ios/lib/core/firebase/firebase_service.dart
- [ ] T028 Запустить build_runner для генерации кода: flutter pub run build_runner build

**Checkpoint**: Инфраструктура готова — можно начинать истории

---

## Phase 3: User Story 5 — Аутентификация (Priority: P5, но блокирует другие)

**Goal**: Регистрация, вход, Sign in with Apple, автоматическая сессия

**Independent Test**: Зарегистрироваться, закрыть приложение, открыть — автоматический вход

**Note**: P5 по приоритету, но блокирует все другие истории

### Тесты для User Story 5

- [ ] T029 [P] [US5] Bloc-тест AuthBloc в ios/test/bloc/auth_bloc_test.dart
- [ ] T030 [P] [US5] Widget-тест LoginPage в ios/test/widget/login_page_test.dart

### Реализация User Story 5

- [ ] T031 [P] [US5] Создать freezed-модель User в ios/lib/features/auth/models/user.dart
- [ ] T032 [P] [US5] Создать freezed-модели AuthTokens, AuthResponse в ios/lib/features/auth/models/auth_tokens.dart
- [ ] T033 [US5] Создать Retrofit API для auth в ios/lib/features/auth/data/auth_api.dart
- [ ] T034 [US5] Реализовать AuthRepository в ios/lib/features/auth/data/auth_repository.dart
- [ ] T035 [US5] Реализовать Sign in with Apple в ios/lib/features/auth/data/apple_auth_service.dart
- [ ] T036 [US5] Создать AuthEvent в ios/lib/features/auth/bloc/auth_event.dart
- [ ] T037 [US5] Создать AuthState в ios/lib/features/auth/bloc/auth_state.dart
- [ ] T038 [US5] Реализовать AuthBloc в ios/lib/features/auth/bloc/auth_bloc.dart
- [ ] T039 [US5] Создать LoginPage с Sign in with Apple и email-формой в ios/lib/features/auth/ui/login_page.dart
- [ ] T040 [P] [US5] Создать виджет AppleSignInButton в ios/lib/features/auth/ui/widgets/apple_sign_in_button.dart
- [ ] T041 [P] [US5] Создать виджет EmailLoginForm в ios/lib/features/auth/ui/widgets/email_login_form.dart
- [ ] T042 [US5] Добавить маршруты auth в app_router.dart
- [ ] T043 [US5] Запустить build_runner для генерации auth-моделей

**Checkpoint**: Аутентификация работает, можно тестировать вход

---

## Phase 4: User Story 3 — Создание персонажа (Priority: P3)

**Goal**: Пошаговый мастер создания D&D-персонажа с валидацией

**Independent Test**: Создать персонажа от начала до конца, увидеть в списке

### Тесты для User Story 3

- [ ] T044 [P] [US3] Unit-тест валидации характеристик в ios/test/unit/character/ability_scores_test.dart
- [ ] T045 [P] [US3] Bloc-тест CharacterBloc в ios/test/bloc/character_bloc_test.dart
- [ ] T046 [P] [US3] Widget-тест CharacterCard в ios/test/widget/character_card_test.dart

### Реализация User Story 3

- [ ] T047 [P] [US3] Создать freezed-модель AbilityScores с расчётом модификаторов в ios/lib/features/character/models/ability_scores.dart
- [ ] T048 [P] [US3] Создать freezed-модель Character в ios/lib/features/character/models/character.dart
- [ ] T049 [P] [US3] Создать freezed-модели DndClass, DndRace в ios/lib/features/character/models/dnd_data.dart
- [ ] T050 [P] [US3] Создать статические данные классов/рас D&D 5e в ios/lib/features/character/data/dnd_reference_data.dart
- [ ] T051 [US3] Создать Retrofit API для characters в ios/lib/features/character/data/character_api.dart
- [ ] T052 [US3] Реализовать CharacterRepository в ios/lib/features/character/data/character_repository.dart
- [ ] T053 [US3] Создать Isar-модель CachedCharacter в ios/lib/features/character/data/cached_character.dart
- [ ] T054 [US3] Реализовать CharacterValidator в ios/lib/features/character/data/character_validator.dart
- [ ] T055 [US3] Создать CharacterEvent в ios/lib/features/character/bloc/character_event.dart
- [ ] T056 [US3] Создать CharacterState в ios/lib/features/character/bloc/character_state.dart
- [ ] T057 [US3] Реализовать CharacterBloc в ios/lib/features/character/bloc/character_bloc.dart
- [ ] T058 [US3] Создать CharacterListPage в ios/lib/features/character/ui/character_list_page.dart
- [ ] T059 [US3] Создать CharacterCreatePage (мастер) в ios/lib/features/character/ui/character_create_page.dart
- [ ] T060 [US3] Создать CharacterDetailPage в ios/lib/features/character/ui/character_detail_page.dart
- [ ] T061 [P] [US3] Создать виджет ClassSelector в ios/lib/features/character/ui/widgets/class_selector.dart
- [ ] T062 [P] [US3] Создать виджет RaceSelector в ios/lib/features/character/ui/widgets/race_selector.dart
- [ ] T063 [P] [US3] Создать виджет AbilityScoresEditor в ios/lib/features/character/ui/widgets/ability_scores_editor.dart
- [ ] T064 [P] [US3] Создать виджет CharacterCard в ios/lib/features/character/ui/widgets/character_card.dart
- [ ] T065 [US3] Добавить маршруты character в app_router.dart
- [ ] T066 [US3] Запустить build_runner для генерации character-моделей

**Checkpoint**: Создание персонажей работает с валидацией D&D 5e

---

## Phase 5: User Story 2 — Конструктор сценариев (Priority: P2)

**Goal**: Создание сценариев через AI, превью с актами/NPC/локациями, версионирование

**Independent Test**: Создать сценарий, просмотреть превью, сделать правку, применить к комнате

### Тесты для User Story 2

- [ ] T067 [P] [US2] Bloc-тест ScenarioBloc в ios/test/bloc/scenario_bloc_test.dart

### Реализация User Story 2

- [ ] T068 [P] [US2] Создать freezed-модели Act, Scene, Npc, Location в ios/lib/features/scenario/models/scenario_content.dart
- [ ] T069 [P] [US2] Создать freezed-модели Scenario, ScenarioVersion в ios/lib/features/scenario/models/scenario.dart
- [ ] T070 [US2] Создать Retrofit API для scenarios в ios/lib/features/scenario/data/scenario_api.dart
- [ ] T071 [US2] Реализовать ScenarioRepository в ios/lib/features/scenario/data/scenario_repository.dart
- [ ] T072 [US2] Создать Isar-модель CachedScenario в ios/lib/features/scenario/data/cached_scenario.dart
- [ ] T073 [US2] Создать ScenarioEvent в ios/lib/features/scenario/bloc/scenario_event.dart
- [ ] T074 [US2] Создать ScenarioState в ios/lib/features/scenario/bloc/scenario_state.dart
- [ ] T075 [US2] Реализовать ScenarioBloc в ios/lib/features/scenario/bloc/scenario_bloc.dart
- [ ] T076 [US2] Создать ScenarioListPage в ios/lib/features/scenario/ui/scenario_list_page.dart
- [ ] T077 [US2] Создать ScenarioBuilderPage (ввод описания) в ios/lib/features/scenario/ui/scenario_builder_page.dart
- [ ] T078 [US2] Создать ScenarioPreviewPage (разворачиваемые секции) в ios/lib/features/scenario/ui/scenario_preview_page.dart
- [ ] T079 [P] [US2] Создать виджет ScenarioCard в ios/lib/features/scenario/ui/widgets/scenario_card.dart
- [ ] T080 [P] [US2] Создать виджет ActExpansionTile в ios/lib/features/scenario/ui/widgets/act_expansion_tile.dart
- [ ] T081 [P] [US2] Создать виджет NpcCard в ios/lib/features/scenario/ui/widgets/npc_card.dart
- [ ] T082 [P] [US2] Создать виджет VersionHistorySheet в ios/lib/features/scenario/ui/widgets/version_history_sheet.dart
- [ ] T083 [US2] Добавить маршруты scenario в app_router.dart
- [ ] T084 [US2] Запустить build_runner для генерации scenario-моделей

**Checkpoint**: Генерация и управление сценариями работает

---

## Phase 6: User Story 4 — Игровое лобби (Priority: P4)

**Goal**: Список комнат, создание комнаты, комната ожидания, запросы на вступление

**Independent Test**: Создать комнату, дождаться игрока, начать игру

### Тесты для User Story 4

- [ ] T085 [P] [US4] Bloc-тест LobbyBloc в ios/test/bloc/lobby_bloc_test.dart

### Реализация User Story 4

- [ ] T086 [P] [US4] Создать freezed-модели Room, RoomPlayer, RoomSummary в ios/lib/features/lobby/models/room.dart
- [ ] T087 [US4] Создать Retrofit API для rooms в ios/lib/features/lobby/data/lobby_api.dart
- [ ] T088 [US4] Реализовать LobbyRepository в ios/lib/features/lobby/data/lobby_repository.dart
- [ ] T089 [US4] Создать LobbyEvent в ios/lib/features/lobby/bloc/lobby_event.dart
- [ ] T090 [US4] Создать LobbyState в ios/lib/features/lobby/bloc/lobby_state.dart
- [ ] T091 [US4] Реализовать LobbyBloc в ios/lib/features/lobby/bloc/lobby_bloc.dart
- [ ] T092 [US4] Создать LobbyPage (список комнат) в ios/lib/features/lobby/ui/lobby_page.dart
- [ ] T093 [US4] Создать RoomCreatePage в ios/lib/features/lobby/ui/room_create_page.dart
- [ ] T094 [US4] Создать WaitingRoomPage в ios/lib/features/lobby/ui/waiting_room_page.dart
- [ ] T095 [P] [US4] Создать виджет RoomCard в ios/lib/features/lobby/ui/widgets/room_card.dart
- [ ] T096 [P] [US4] Создать виджет PlayerAvatar в ios/lib/features/lobby/ui/widgets/player_avatar.dart
- [ ] T097 [P] [US4] Создать виджет JoinRequestDialog в ios/lib/features/lobby/ui/widgets/join_request_dialog.dart
- [ ] T098 [US4] Добавить маршруты lobby в app_router.dart
- [ ] T099 [US4] Запустить build_runner для генерации lobby-моделей

**Checkpoint**: Лобби работает, можно создавать/присоединяться к комнатам

---

## Phase 7: User Story 1 — Игровая сессия (Priority: P1)

**Goal**: Чат-интерфейс, WebSocket, броски кубиков, голосовой ввод/вывод, TTS

**Independent Test**: Открыть сессию, отправить 3 действия (текст + голос), бросить кубики

### Тесты для User Story 1

- [ ] T100 [P] [US1] Unit-тест расчёта бросков кубиков в ios/test/unit/game_session/dice_calculation_test.dart
- [ ] T101 [P] [US1] Bloc-тест SessionBloc в ios/test/bloc/session_bloc_test.dart
- [ ] T102 [P] [US1] Widget-тест DiceRoller в ios/test/widget/dice_roller_test.dart

### Реализация User Story 1

- [ ] T103 [P] [US1] Создать freezed-модели Message, DiceRequest, DiceResult в ios/lib/features/game_session/models/message.dart
- [ ] T104 [P] [US1] Создать freezed-модели GameSession, WorldState в ios/lib/features/game_session/models/game_session.dart
- [ ] T105 [P] [US1] Создать freezed-модели ClientMessage, ServerMessage (WebSocket) в ios/lib/features/game_session/models/websocket_messages.dart
- [ ] T106 [US1] Создать Retrofit API для sessions в ios/lib/features/game_session/data/session_api.dart
- [ ] T107 [US1] Реализовать WebSocketHandler для сессии в ios/lib/features/game_session/data/websocket_handler.dart
- [ ] T108 [US1] Реализовать SessionRepository в ios/lib/features/game_session/data/session_repository.dart
- [ ] T109 [US1] Реализовать VoiceService (TTS/STT) в ios/lib/features/game_session/data/voice_service.dart
- [ ] T110 [US1] Создать SessionEvent в ios/lib/features/game_session/bloc/session_event.dart
- [ ] T111 [US1] Создать SessionState в ios/lib/features/game_session/bloc/session_state.dart
- [ ] T112 [US1] Реализовать SessionBloc в ios/lib/features/game_session/bloc/session_bloc.dart
- [ ] T113 [US1] Создать GameSessionPage в ios/lib/features/game_session/ui/game_session_page.dart
- [ ] T114 [P] [US1] Создать виджет ChatMessageList в ios/lib/features/game_session/ui/widgets/chat_message_list.dart
- [ ] T115 [P] [US1] Создать виджет ChatInputBar в ios/lib/features/game_session/ui/widgets/chat_input_bar.dart
- [ ] T116 [P] [US1] Создать виджет DiceRoller с анимацией в ios/lib/features/game_session/ui/widgets/dice_roller.dart
- [ ] T117 [P] [US1] Создать виджет VoiceInputButton в ios/lib/features/game_session/ui/widgets/voice_input_button.dart
- [ ] T118 [P] [US1] Создать виджет DmThinkingIndicator в ios/lib/features/game_session/ui/widgets/dm_thinking_indicator.dart
- [ ] T119 [US1] Добавить Lottie-анимации кубиков в ios/assets/animations/
- [ ] T120 [US1] Добавить маршруты game_session в app_router.dart
- [ ] T121 [US1] Запустить build_runner для генерации session-моделей

**Checkpoint**: Основной игровой процесс работает — чат, кубики, голос

---

## Phase 8: User Story 6 — Профиль и история (Priority: P6)

**Goal**: Просмотр профиля, редактирование, вкладки с персонажами/сценариями/историей

**Independent Test**: Просмотреть профиль, изменить имя, посмотреть историю игр

### Тесты для User Story 6

- [ ] T122 [P] [US6] Widget-тест ProfilePage в ios/test/widget/profile_page_test.dart

### Реализация User Story 6

- [ ] T123 [US6] Создать Retrofit API для profile в ios/lib/features/profile/data/profile_api.dart
- [ ] T124 [US6] Реализовать ProfileRepository в ios/lib/features/profile/data/profile_repository.dart
- [ ] T125 [US6] Создать ProfileEvent в ios/lib/features/profile/bloc/profile_event.dart
- [ ] T126 [US6] Создать ProfileState в ios/lib/features/profile/bloc/profile_state.dart
- [ ] T127 [US6] Реализовать ProfileBloc в ios/lib/features/profile/bloc/profile_bloc.dart
- [ ] T128 [US6] Создать ProfilePage с вкладками в ios/lib/features/profile/ui/profile_page.dart
- [ ] T129 [US6] Создать SettingsPage в ios/lib/features/profile/ui/settings_page.dart
- [ ] T130 [P] [US6] Создать виджет GameHistoryCard в ios/lib/features/profile/ui/widgets/game_history_card.dart
- [ ] T131 [US6] Добавить маршруты profile в app_router.dart
- [ ] T132 [US6] Запустить build_runner для генерации profile-моделей

**Checkpoint**: Профиль работает с историей игр

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Улучшения, затрагивающие несколько историй

- [ ] T133 [P] Добавить VoiceOver-метки для всех интерактивных элементов (FR-050)
- [ ] T134 [P] Проверить минимальные области касания 44x44pt (FR-052)
- [ ] T135 [P] Реализовать deep linking для комнат и сценариев в app_router.dart
- [ ] T136 [P] Реализовать обработку оффлайн-режима и синхронизацию
- [ ] T137 [P] Настроить навигацию по вкладкам: Играть, Сценарии, Персонажи, Профиль
- [ ] T138 [P] Добавить тактильную обратную связь (HapticFeedback) для бросков кубиков
- [ ] T139 Создать интеграционный тест полного игрового флоу в ios/test/integration/game_flow_test.dart
- [ ] T140 Запустить валидацию quickstart.md
- [ ] T141 Финальный прогон всех тестов: flutter test

---

## Dependencies & Execution Order

### Зависимости фаз

- **Setup (Phase 1)**: Без зависимостей
- **Foundational (Phase 2)**: Зависит от Setup — БЛОКИРУЕТ все истории
- **US5 Auth (Phase 3)**: Зависит от Foundational — БЛОКИРУЕТ все истории
- **US3 Characters (Phase 4)**: Зависит от US5 (аутентификация)
- **US2 Scenarios (Phase 5)**: Зависит от US5 (аутентификация)
- **US4 Lobby (Phase 6)**: Зависит от US3 + US2 (нужны персонажи и сценарии)
- **US1 Sessions (Phase 7)**: Зависит от US4 (нужны комнаты)
- **US6 Profile (Phase 8)**: Зависит от US5, может параллелиться с US3-US4
- **Polish (Phase 9)**: Зависит от всех историй

### Параллельные возможности

После завершения US5 (Auth):
- US3 (Characters) и US2 (Scenarios) и US6 (Profile) — **параллельно**

После US3 + US2:
- US4 (Lobby) — зависит от обоих

### Внутри каждой истории

- Тесты ДОЛЖНЫ быть написаны и ПАДАТЬ до реализации
- Модели (freezed) перед API/репозиториями
- Bloc перед UI
- Виджеты [P] — параллельно
- build_runner после каждого модуля

---

## Parallel Example: После US5

```bash
# Developer A: Characters (US3)
Task: "Создать freezed-модель Character"
Task: "Реализовать CharacterBloc"

# Developer B: Scenarios (US2) — параллельно
Task: "Создать freezed-модели Scenario"
Task: "Реализовать ScenarioBloc"

# Developer C: Profile (US6) — параллельно
Task: "Реализовать ProfileBloc"
Task: "Создать ProfilePage"
```

---

## Implementation Strategy

### MVP First (Минимальный играбельный продукт)

1. Setup + Foundational → Инфраструктура готова
2. US5 (Auth) → Вход работает
3. US3 (Characters) → Можно создавать персонажей
4. US2 (Scenarios) → Можно создавать сценарии
5. US4 (Lobby) → Можно создавать комнаты
6. US1 (Sessions) → **MVP ГОТОВ** — можно играть!
7. US6 (Profile) → Расширенная функциональность

### Suggested MVP Scope

**Минимум для демонстрации**: Phases 1-7 (без профиля)
- Пользователь может войти
- Создать персонажа
- Создать или выбрать сценарий
- Создать комнату
- Играть сессию с AI DM

---

## Summary

| Метрика | Значение |
|---------|----------|
| **Всего задач** | 141 |
| **Setup** | 7 задач |
| **Foundational** | 21 задач |
| **US5 Auth** | 15 задач |
| **US3 Characters** | 23 задачи |
| **US2 Scenarios** | 18 задач |
| **US4 Lobby** | 15 задач |
| **US1 Sessions** | 22 задачи |
| **US6 Profile** | 11 задач |
| **Polish** | 9 задач |
| **Параллельные возможности** | US3+US2+US6 после Auth |
| **MVP scope** | Phases 1-7 (без US6) |
