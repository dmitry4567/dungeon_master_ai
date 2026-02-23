# План реализации: Backend API AI Dungeon Master

**Ветка**: `002-backend-api` | **Дата**: 2026-02-21 | **Спецификация**: [spec.md](./spec.md)
**Вводные данные**: Спецификация функции из `/specs/002-backend-api/spec.md`

## Краткое описание

Backend API сервер, предоставляющий функциональность AI-мастера для ролевой игры D&D 5e. Сервер оркестрирует Claude AI для генерации нарратива и извлечения состояния, управляет мультиплеерными сессиями реального времени через WebSocket, обрабатывает генерацию сценариев с контролем версий и предоставляет RESTful эндпоинты для аутентификации, персонажей, комнат и управления пользователями.

## Технический контекст

**Язык/Версия**: Python 3.11+
**Основные зависимости**: FastAPI, Anthropic SDK, SQLAlchemy, Pydantic, python-jose (JWT), websockets
**Хранилище**: PostgreSQL (постоянное), Redis (кэш/pub-sub), Cloudflare R2 (аудиофайлы)
**Тестирование**: pytest, pytest-asyncio, httpx (async test client)
**Целевая платформа**: Linux-сервер (Railway/Render для MVP, AWS/GCP для масштабирования)
**Тип проекта**: Единый backend API
**Цели производительности**: 100 одновременных WebSocket-соединений, <10с время ответа AI (95-й перцентиль)
**Ограничения**: <$1.50 стоимость AI на 2-3 часовую сессию, <500мс задержка действие-трансляция
**Масштаб/Объём**: MVP на ~100 одновременных пользователей, 20 активных игровых комнат

## Проверка конституции

*КОНТРОЛЬНАЯ ТОЧКА: Должна пройти перед Фазой 0 исследования. Перепроверить после Фазы 1 проектирования.*

| Принцип | Статус | Примечания по реализации |
|---------|--------|--------------------------|
| I. AI только на бэкенде | ✅ ПРОЙДЕНО | Все AI-вызовы в модуле `ai_service`; нет клиентского AI |
| II. Мультиплеер реального времени | ✅ ПРОЙДЕНО | WebSocket для сессий; Redis pub/sub для трансляции; PostgreSQL persistence |
| III. Безопасность контента | ✅ ПРОЙДЕНО | Безопасность Anthropic в системном промпте; кастомный слой модерации (FR-041-043) |
| IV. Оптимизация затрат | ✅ ПРОЙДЕНО | Кэширование промптов (FR-030); Haiku для извлечения состояния (FR-034); лимит 15 сообщений (FR-031) |
| V. Разработка через тестирование | ✅ ПРОЙДЕНО | pytest с контрактной/интеграционной/unit структурой |
| VI. Правила D&D 5e | ✅ ПРОЙДЕНО | Валидация персонажа (FR-010); механики бросков по 5e |

**Результат контрольной точки**: ПРОЙДЕНО — Все принципы конституции удовлетворены проектом.

## Структура проекта

### Документация (эта функция)

```text
specs/002-backend-api/
├── plan.md              # Этот файл
├── research.md          # Результат Фазы 0
├── data-model.md        # Результат Фазы 1
├── quickstart.md        # Результат Фазы 1
├── contracts/           # Результат Фазы 1 (OpenAPI спецификации)
└── tasks.md             # Результат Фазы 2 (команда /speckit.tasks)
```

### Исходный код (корень репозитория)

```text
backend/
├── src/
│   ├── api/
│   │   ├── __init__.py
│   │   ├── main.py              # Точка входа FastAPI
│   │   ├── dependencies.py       # Внедрение зависимостей
│   │   ├── middleware.py         # Auth, CORS, rate limiting
│   │   └── routes/
│   │       ├── auth.py           # /auth эндпоинты
│   │       ├── users.py          # /users эндпоинты
│   │       ├── characters.py     # /characters эндпоинты
│   │       ├── scenarios.py      # /scenarios эндпоинты
│   │       ├── rooms.py          # /rooms эндпоинты
│   │       ├── sessions.py       # /sessions эндпоинты (REST)
│   │       └── websocket.py      # Обработчик WebSocket
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── character.py
│   │   ├── scenario.py
│   │   ├── room.py
│   │   ├── session.py
│   │   └── message.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py       # JWT, Apple Sign In
│   │   ├── user_service.py
│   │   ├── character_service.py
│   │   ├── scenario_service.py
│   │   ├── lobby_service.py
│   │   ├── session_service.py
│   │   ├── ai_service.py         # Оркестрация Claude
│   │   ├── state_extractor.py    # Извлечение состояния мира
│   │   └── voice_service.py      # TTS/STT прокси
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py             # Настройки из env
│   │   ├── database.py           # Настройка SQLAlchemy
│   │   ├── redis.py              # Redis-клиент
│   │   ├── storage.py            # R2/S3-клиент
│   │   └── security.py           # Хэширование паролей, JWT утилиты
│   └── schemas/
│       ├── __init__.py
│       ├── auth.py               # Pydantic схемы для auth
│       ├── user.py
│       ├── character.py
│       ├── scenario.py
│       ├── room.py
│       ├── session.py
│       └── websocket.py          # Схемы WebSocket-сообщений
├── tests/
│   ├── conftest.py               # pytest фикстуры
│   ├── contract/                 # Контрактные тесты API
│   │   ├── test_auth_contract.py
│   │   ├── test_characters_contract.py
│   │   └── test_scenarios_contract.py
│   ├── integration/              # Интеграционные тесты сервисов
│   │   ├── test_ai_orchestration.py
│   │   ├── test_websocket_session.py
│   │   └── test_scenario_generation.py
│   └── unit/                     # Unit-тесты
│       ├── test_state_extractor.py
│       ├── test_dice_parser.py
│       └── test_dnd_validation.py
├── alembic/                      # Миграции базы данных
│   ├── versions/
│   └── env.py
├── pyproject.toml                # Зависимости, конфигурация инструментов
├── Dockerfile
├── docker-compose.yml            # Локальная разработка с Postgres, Redis
└── .env.example
```

**Решение по структуре**: Единый backend-проект с модульным сервисным слоем. Сервисы изолированы для тестируемости; роуты — тонкие обёртки над сервисами. Обработка WebSocket централизована в одном модуле роутов с Redis pub/sub для масштабирования на несколько инстансов.

## Отслеживание сложности

> Нарушений конституции для обоснования нет.

| Нарушение | Почему необходимо | Простая альтернатива отвергнута, потому что |
|-----------|-------------------|---------------------------------------------|
| — | — | — |
