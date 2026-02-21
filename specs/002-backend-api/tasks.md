# Tasks: Backend API AI Dungeon Master

**Input**: Design documents from `/specs/002-backend-api/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/openapi.yaml, research.md

**Tests**: Включены по умолчанию согласно конституции проекта (V. Разработка через тестирование)

**Organization**: Задачи сгруппированы по пользовательским историям для независимой реализации и тестирования

## Формат: `[ID] [P?] [Story] Description`

- **[P]**: Можно выполнять параллельно (разные файлы, нет зависимостей)
- **[Story]**: К какой пользовательской истории относится задача (US1, US2, ...)
- Включены точные пути к файлам

---

## Phase 1: Setup (Инициализация проекта)

**Purpose**: Создание структуры проекта и базовой конфигурации

- [ ] T001 Создать структуру проекта согласно plan.md в backend/
- [ ] T002 Инициализировать Python-проект с pyproject.toml и зависимостями (FastAPI, SQLAlchemy, Pydantic, python-jose, anthropic, websockets, argon2-cffi)
- [ ] T003 [P] Настроить ruff для линтинга в pyproject.toml
- [ ] T004 [P] Создать docker-compose.yml для локальной разработки (PostgreSQL, Redis)
- [ ] T005 [P] Создать .env.example с переменными окружения
- [ ] T006 [P] Настроить pytest и pytest-asyncio в pyproject.toml

---

## Phase 2: Foundational (Базовая инфраструктура)

**Purpose**: Инфраструктура, которая ДОЛЖНА быть готова до реализации любой пользовательской истории

**CRITICAL**: Никакая работа над историями не может начаться до завершения этой фазы

- [ ] T007 Реализовать конфигурацию приложения в backend/src/core/config.py (Pydantic Settings)
- [ ] T008 [P] Настроить подключение к базе данных SQLAlchemy в backend/src/core/database.py
- [ ] T009 [P] Настроить Redis-клиент в backend/src/core/redis.py
- [ ] T010 [P] Настроить S3/R2-клиент в backend/src/core/storage.py
- [ ] T011 Создать миграционный фреймворк Alembic в backend/alembic/
- [ ] T012 Реализовать утилиты безопасности (хэширование паролей Argon2id, JWT) в backend/src/core/security.py
- [ ] T013 Создать базовую модель User в backend/src/models/user.py
- [ ] T014 Создать начальную миграцию с таблицей users в backend/alembic/versions/001_initial.py
- [ ] T015 Реализовать точку входа FastAPI в backend/src/api/main.py (без роутов)
- [ ] T016 [P] Реализовать middleware: CORS, rate limiting в backend/src/api/middleware.py
- [ ] T017 [P] Реализовать структурированное логирование JSON в backend/src/core/logging.py
- [ ] T018 [P] Реализовать correlation ID middleware в backend/src/api/middleware.py
- [ ] T019 Создать базовые Pydantic-схемы ошибок в backend/src/schemas/common.py
- [ ] T020 Создать conftest.py с фикстурами pytest в backend/tests/conftest.py

**Checkpoint**: Инфраструктура готова — можно начинать реализацию пользовательских историй

---

## Phase 3: User Story 3 — Аутентификация (Priority: P3, но блокирует другие)

**Goal**: Регистрация, вход, JWT-токены, Sign in with Apple

**Independent Test**: Зарегистрировать пользователя, получить токен, использовать для защищённого эндпоинта

**Note**: Хотя это P3 по приоритету, аутентификация блокирует все другие истории, поэтому реализуется первой

### Тесты для User Story 3

- [ ] T021 [P] [US3] Контрактный тест POST /auth/register в backend/tests/contract/test_auth_contract.py
- [ ] T022 [P] [US3] Контрактный тест POST /auth/login в backend/tests/contract/test_auth_contract.py
- [ ] T023 [P] [US3] Контрактный тест POST /auth/refresh в backend/tests/contract/test_auth_contract.py
- [ ] T024 [P] [US3] Контрактный тест POST /auth/apple в backend/tests/contract/test_auth_contract.py
- [ ] T025 [P] [US3] Контрактный тест GET/PATCH /users/me в backend/tests/contract/test_users_contract.py

### Реализация User Story 3

- [ ] T026 [P] [US3] Создать Pydantic-схемы аутентификации в backend/src/schemas/auth.py
- [ ] T027 [P] [US3] Создать Pydantic-схемы пользователя в backend/src/schemas/user.py
- [ ] T028 [US3] Реализовать AuthService (регистрация, логин, refresh) в backend/src/services/auth_service.py
- [ ] T029 [US3] Реализовать верификацию Sign in with Apple в backend/src/services/auth_service.py
- [ ] T030 [US3] Реализовать UserService (получение, обновление профиля) в backend/src/services/user_service.py
- [ ] T031 [US3] Реализовать dependency для получения текущего пользователя в backend/src/api/dependencies.py
- [ ] T032 [US3] Реализовать роуты /auth/* в backend/src/api/routes/auth.py
- [ ] T033 [US3] Реализовать роуты /users/me в backend/src/api/routes/users.py
- [ ] T034 [US3] Подключить роуты auth и users к main.py

**Checkpoint**: Аутентификация работает независимо, можно тестировать регистрацию/вход/токены

---

## Phase 4: User Story 5 — Управление персонажами (Priority: P5)

**Goal**: CRUD персонажей с валидацией D&D 5e

**Independent Test**: Создать персонажа, получить список, использовать в комнате

### Тесты для User Story 5

- [ ] T035 [P] [US5] Контрактный тест CRUD /characters в backend/tests/contract/test_characters_contract.py
- [ ] T036 [P] [US5] Unit-тест валидации D&D 5e в backend/tests/unit/test_dnd_validation.py

### Реализация User Story 5

- [ ] T037 [P] [US5] Создать модель Character в backend/src/models/character.py
- [ ] T038 [US5] Добавить миграцию для таблицы characters в backend/alembic/versions/002_characters.py
- [ ] T039 [P] [US5] Создать Pydantic-схемы персонажа в backend/src/schemas/character.py
- [ ] T040 [US5] Реализовать валидатор D&D 5e (классы, расы, характеристики) в backend/src/services/dnd_validator.py
- [ ] T041 [US5] Реализовать CharacterService в backend/src/services/character_service.py
- [ ] T042 [US5] Реализовать роуты /characters/* в backend/src/api/routes/characters.py
- [ ] T043 [US5] Подключить роуты characters к main.py

**Checkpoint**: CRUD персонажей работает с валидацией D&D 5e

---

## Phase 5: User Story 2 — Генерация сценариев (Priority: P2)

**Goal**: AI-генерация сценариев, версионирование, валидация логики

**Independent Test**: Отправить описание, получить структурированный JSON с актами, NPC, локациями

### Тесты для User Story 2

- [ ] T044 [P] [US2] Контрактный тест POST /scenarios в backend/tests/contract/test_scenarios_contract.py
- [ ] T045 [P] [US2] Контрактный тест POST /scenarios/{id}/refine в backend/tests/contract/test_scenarios_contract.py
- [ ] T046 [P] [US2] Интеграционный тест генерации сценария в backend/tests/integration/test_scenario_generation.py

### Реализация User Story 2

- [ ] T047 [P] [US2] Создать модель Scenario в backend/src/models/scenario.py
- [ ] T048 [P] [US2] Создать модель ScenarioVersion в backend/src/models/scenario.py
- [ ] T049 [US2] Добавить миграцию для таблиц scenarios, scenario_versions в backend/alembic/versions/003_scenarios.py
- [ ] T050 [P] [US2] Создать Pydantic-схемы сценария в backend/src/schemas/scenario.py
- [ ] T051 [US2] Реализовать базовый AI-сервис (обёртка над Anthropic SDK) в backend/src/services/ai_service.py
- [ ] T052 [US2] Реализовать генерацию сценария через Claude в backend/src/services/scenario_service.py
- [ ] T053 [US2] Реализовать валидацию логики сценария (достижимость актов, ссылки на NPC) в backend/src/services/scenario_service.py
- [ ] T054 [US2] Реализовать версионирование и восстановление в backend/src/services/scenario_service.py
- [ ] T055 [US2] Реализовать роуты /scenarios/* в backend/src/api/routes/scenarios.py
- [ ] T056 [US2] Подключить роуты scenarios к main.py

**Checkpoint**: Генерация и управление сценариями работает независимо

---

## Phase 6: User Story 4 — Игровые комнаты и лобби (Priority: P4)

**Goal**: Создание комнат, вход/выход игроков, статус готовности, старт игры

**Independent Test**: Создать комнату, присоединить игрока, отметить готовность, запустить игру

### Тесты для User Story 4

- [ ] T057 [P] [US4] Контрактный тест CRUD /rooms в backend/tests/contract/test_rooms_contract.py
- [ ] T058 [P] [US4] Контрактный тест /rooms/{id}/join, /ready, /start в backend/tests/contract/test_rooms_contract.py

### Реализация User Story 4

- [ ] T059 [P] [US4] Создать модель Room в backend/src/models/room.py
- [ ] T060 [P] [US4] Создать модель RoomPlayer в backend/src/models/room.py
- [ ] T061 [US4] Добавить миграцию для таблиц rooms, room_players в backend/alembic/versions/004_rooms.py
- [ ] T062 [P] [US4] Создать Pydantic-схемы комнаты в backend/src/schemas/room.py
- [ ] T063 [US4] Реализовать LobbyService (создание, присоединение, готовность) в backend/src/services/lobby_service.py
- [ ] T064 [US4] Реализовать логику старта игры (создание GameSession) в backend/src/services/lobby_service.py
- [ ] T065 [US4] Реализовать роуты /rooms/* в backend/src/api/routes/rooms.py
- [ ] T066 [US4] Подключить роуты rooms к main.py

**Checkpoint**: Лобби и управление комнатами работает, можно запускать игру

---

## Phase 7: User Story 1 — Игровая сессия с AI DM (Priority: P1)

**Goal**: WebSocket для игры, AI-оркестрация, извлечение состояния, трансляция

**Independent Test**: Отправить действие через WebSocket, получить ответ AI, проверить трансляцию

### Тесты для User Story 1

- [ ] T067 [P] [US1] Unit-тест парсера запросов бросков кубиков в backend/tests/unit/test_dice_parser.py
- [ ] T068 [P] [US1] Unit-тест извлечения состояния в backend/tests/unit/test_state_extractor.py
- [ ] T069 [P] [US1] Интеграционный тест AI-оркестрации в backend/tests/integration/test_ai_orchestration.py
- [ ] T070 [P] [US1] Интеграционный тест WebSocket-сессии в backend/tests/integration/test_websocket_session.py

### Реализация User Story 1

- [ ] T071 [P] [US1] Создать модель GameSession в backend/src/models/session.py
- [ ] T072 [P] [US1] Создать модель SessionMessage в backend/src/models/message.py
- [ ] T073 [US1] Добавить миграцию для таблиц game_sessions, session_messages в backend/alembic/versions/005_sessions.py
- [ ] T074 [P] [US1] Создать Pydantic-схемы сессии в backend/src/schemas/session.py
- [ ] T075 [P] [US1] Создать Pydantic-схемы WebSocket-сообщений в backend/src/schemas/websocket.py
- [ ] T076 [US1] Расширить AI-сервис: конструирование промптов мастера с контекстом в backend/src/services/ai_service.py
- [ ] T077 [US1] Реализовать кэширование промптов для оптимизации затрат в backend/src/services/ai_service.py
- [ ] T078 [US1] Реализовать парсер запросов бросков кубиков из ответов AI в backend/src/services/dice_parser.py
- [ ] T079 [US1] Реализовать StateExtractor (извлечение изменений состояния через Haiku) в backend/src/services/state_extractor.py
- [ ] T080 [US1] Реализовать SessionService (управление сессией, сообщения) в backend/src/services/session_service.py
- [ ] T081 [US1] Реализовать WebSocket-хендлер с Redis pub/sub в backend/src/api/routes/websocket.py
- [ ] T082 [US1] Реализовать трансляцию сообщений всем игрокам в комнате в backend/src/api/routes/websocket.py
- [ ] T083 [US1] Реализовать REST-роуты /sessions/* в backend/src/api/routes/sessions.py
- [ ] T084 [US1] Подключить роуты sessions и WebSocket к main.py

**Checkpoint**: Основная игровая механика работает — AI отвечает, состояние обновляется, игроки синхронизированы

---

## Phase 8: User Story 6 — Голосовой прокси (Priority: P6)

**Goal**: TTS/STT через внешние сервисы, хранение аудио

**Independent Test**: Отправить текст на TTS, получить URL аудио; отправить аудио на STT, получить текст

### Тесты для User Story 6

- [ ] T085 [P] [US6] Контрактный тест TTS/STT эндпоинтов (mock внешних сервисов) в backend/tests/contract/test_voice_contract.py

### Реализация User Story 6

- [ ] T086 [P] [US6] Создать Pydantic-схемы для voice в backend/src/schemas/voice.py
- [ ] T087 [US6] Реализовать VoiceService (TTS, STT, хранение) в backend/src/services/voice_service.py
- [ ] T088 [US6] Реализовать роуты /voice/* в backend/src/api/routes/voice.py
- [ ] T089 [US6] Подключить роуты voice к main.py

**Checkpoint**: Голосовая функциональность работает независимо

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Улучшения, затрагивающие несколько историй

- [ ] T090 [P] Реализовать фильтры модерации контента в backend/src/services/moderation_service.py
- [ ] T091 [P] Добавить метрики latency и error rate в backend/src/api/middleware.py
- [ ] T092 [P] Реализовать обработку граничных случаев: недоступность AI-провайдера (503 + retry-after)
- [ ] T093 [P] Реализовать обработку переподключения WebSocket (синхронизация пропущенных сообщений)
- [ ] T094 [P] Реализовать очередь действий с метками времени для параллельных действий игроков
- [ ] T095 Создать Dockerfile для production в backend/Dockerfile
- [ ] T096 Запустить валидацию quickstart.md
- [ ] T097 Финальный прогон всех тестов и проверка покрытия

---

## Dependencies & Execution Order

### Зависимости фаз

- **Setup (Phase 1)**: Без зависимостей — можно начинать сразу
- **Foundational (Phase 2)**: Зависит от Setup — БЛОКИРУЕТ все истории
- **US3 Auth (Phase 3)**: Зависит от Foundational — БЛОКИРУЕТ все остальные истории (требуется аутентификация)
- **US5 Characters (Phase 4)**: Зависит от US3 (аутентификация)
- **US2 Scenarios (Phase 5)**: Зависит от US3 (аутентификация)
- **US4 Rooms (Phase 6)**: Зависит от US3, US5, US2 (нужны персонажи и сценарии)
- **US1 Sessions (Phase 7)**: Зависит от US4 (нужны комнаты)
- **US6 Voice (Phase 8)**: Зависит от US3 (аутентификация), может выполняться параллельно с US4-US1
- **Polish (Phase 9)**: Зависит от завершения всех историй

### Параллельные возможности

После завершения US3 (аутентификация):
- US5 (Characters) и US2 (Scenarios) могут выполняться параллельно
- US6 (Voice) может выполняться параллельно с US4, US1

### Внутри каждой истории

- Тесты ДОЛЖНЫ быть написаны и ПАДАТЬ до реализации
- Модели перед сервисами
- Сервисы перед роутами
- Коммит после каждой задачи или логической группы

---

## Parallel Example: После US3

```bash
# Developer A: Characters (US5)
Task: "Создать модель Character в backend/src/models/character.py"
Task: "Реализовать CharacterService в backend/src/services/character_service.py"

# Developer B: Scenarios (US2) - параллельно
Task: "Создать модель Scenario в backend/src/models/scenario.py"
Task: "Реализовать генерацию сценария в backend/src/services/scenario_service.py"

# Developer C: Voice (US6) - параллельно
Task: "Реализовать VoiceService в backend/src/services/voice_service.py"
```

---

## Implementation Strategy

### MVP First (Минимальная игровая сессия)

1. Setup + Foundational → Инфраструктура готова
2. US3 (Auth) → Аутентификация работает
3. US5 (Characters) → Можно создавать персонажей
4. US2 (Scenarios) → Можно генерировать сценарии
5. US4 (Rooms) → Можно создавать комнаты
6. US1 (Sessions) → **MVP ГОТОВ** — можно играть!
7. US6 (Voice) → Расширенная функциональность

### Suggested MVP Scope

**Минимум для демонстрации**: Phases 1-7 (без голоса)
- Пользователь может зарегистрироваться
- Создать персонажа
- Сгенерировать сценарий
- Создать комнату
- Играть сессию с AI DM

---

## Summary

| Метрика | Значение |
|---------|----------|
| **Всего задач** | 97 |
| **Setup** | 6 задач |
| **Foundational** | 14 задач |
| **US3 Auth** | 14 задач |
| **US5 Characters** | 9 задач |
| **US2 Scenarios** | 13 задач |
| **US4 Rooms** | 10 задач |
| **US1 Sessions** | 18 задач |
| **US6 Voice** | 5 задач |
| **Polish** | 8 задач |
| **Параллельные возможности** | US5+US2+US6 после Auth |
| **MVP scope** | Phases 1-7 (без US6) |
