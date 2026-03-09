# Быстрый старт: Backend API AI Dungeon Master

**Функция**: 002-backend-api
**Дата**: 2026-02-21

## Предварительные требования

- Python 3.11+
- Docker & Docker Compose (для локальных PostgreSQL и Redis)
- API-ключ Anthropic

## Установка

### 1. Клонирование и установка

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # На Windows: .venv\Scripts\activate
pip install -e ".[dev]"
```

### 2. Конфигурация окружения

Скопируйте `.env.example` в `.env` и заполните:

```bash
# База данных
DATABASE_URL=postgresql+asyncpg://aidm:aidm@localhost:5432/aidm

# Redis
=redis://localhost:6379/0

# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# JWT
JWT_SECRET_KEY=your-secret-key-min-32-chars
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=10080  # 7 дней
JWT_REFRESH_TOKEN_EXPIRE_DAYS=30

# Apple Sign In
APPLE_CLIENT_ID=com.yourcompany.aidm

# Хранилище (R2/S3)
S3_ENDPOINT=https://your-account.r2.cloudflarestorage.com
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
S3_BUCKET=aidm-audio
```

### 3. Запуск инфраструктуры

```bash
docker-compose up -d
```

Это запускает:
- PostgreSQL на порту 5432
- Redis на порту 6379

### 4. Применение миграций

```bash
alembic upgrade head
```

### 5. Запуск сервера разработки

```bash
uvicorn src.api.main:app --reload --port 8000
```

API доступен по адресу: http://localhost:8000
Документация: http://localhost:8000/docs

## Проверка установки

### Проверка работоспособности

```bash
curl http://localhost:8000/health
# {"status": "ok", "database": "connected", "redis": "connected"}
```

### Регистрация пользователя

```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpass123", "name": "Тестовый пользователь"}'
```

### Создание персонажа

```bash
TOKEN="<access_token из ответа регистрации>"

curl -X POST http://localhost:8000/api/v1/characters \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Торин",
    "class": "fighter",
    "race": "dwarf",
    "ability_scores": {
      "strength": 16,
      "dexterity": 12,
      "constitution": 15,
      "intelligence": 10,
      "wisdom": 13,
      "charisma": 8
    },
    "backstory": "Бывалый воин из горных залов."
  }'
```

### Генерация сценария

```bash
curl -X POST http://localhost:8000/api/v1/scenarios \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"description": "Заброшенная шахта гномов, где пробудилось древнее зло. Партия должна найти артефакт и остановить нежить."}'
```

### Создание комнаты и старт игры

```bash
# Создание комнаты
curl -X POST http://localhost:8000/api/v1/rooms \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "Тестовая комната", "scenario_version_id": "<version_id>", "max_players": 4}'

# Отметка готовности (с персонажем)
curl -X POST http://localhost:8000/api/v1/rooms/<room_id>/ready \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"character_id": "<character_id>", "ready": true}'

# Старт игры (только хост)
curl -X POST http://localhost:8000/api/v1/rooms/<room_id>/start \
  -H "Authorization: Bearer $TOKEN"
```

### Подключение к игровой сессии (WebSocket)

```python
import asyncio
import websockets
import json

async def play():
    uri = f"ws://localhost:8000/api/v1/ws/session/<room_id>?token={TOKEN}"
    async with websockets.connect(uri) as ws:
        # Отправка действия
        await ws.send(json.dumps({
            "type": "player_action",
            "content": "Я осматриваю вход в шахту"
        }))

        # Получение ответа мастера
        response = await ws.recv()
        print(json.loads(response))

asyncio.run(play())
```

## Запуск тестов

```bash
# Все тесты
pytest

# С покрытием
pytest --cov=src --cov-report=html

# Конкретный файл теста
pytest tests/unit/test_state_extractor.py

# Интеграционные тесты (требуют Docker)
pytest tests/integration/
```

## Структура проекта

```
backend/
├── src/
│   ├── api/           # FastAPI роуты и middleware
│   ├── models/        # SQLAlchemy модели
│   ├── services/      # Бизнес-логика
│   ├── core/          # Конфигурация, база данных, безопасность
│   └── schemas/       # Pydantic схемы
├── tests/
│   ├── contract/      # Контрактные тесты API
│   ├── integration/   # Интеграционные тесты сервисов
│   └── unit/          # Unit-тесты
├── alembic/           # Миграции базы данных
└── pyproject.toml     # Зависимости
```

## Типичные задачи

### Создание миграции

```bash
alembic revision --autogenerate -m "add new field to users"
```

### Сброс базы данных

```bash
docker-compose down -v
docker-compose up -d
alembic upgrade head
```

### Просмотр логов

```bash
# Логи приложения
uvicorn src.api.main:app --reload --log-level debug

# Логи Docker-сервисов
docker-compose logs -f postgres
docker-compose logs -f redis
```

## Устранение неполадок

### "Connection refused" к PostgreSQL

```bash
# Проверить, запущен ли контейнер
docker ps | grep postgres

# Перезапустить при необходимости
docker-compose restart postgres
```

### "Anthropic API error"

- Проверьте, что `ANTHROPIC_API_KEY` установлен правильно
- Проверьте, что у API-ключа достаточно кредитов
- Проверьте сетевой доступ к api.anthropic.com

### "WebSocket connection failed"

- Убедитесь, что сессия существует и активна
- Проверьте валидность JWT-токена
- Проверьте, что токен передаётся как query-параметр, не заголовок
