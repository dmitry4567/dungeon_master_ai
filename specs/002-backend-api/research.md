# Исследование: Backend API AI Dungeon Master

**Функция**: 002-backend-api
**Дата**: 2026-02-21

## 1. AI-оркестрация с Anthropic Claude

### Решение
Использовать Anthropic Python SDK с Claude Sonnet 4 для ответов мастера и генерации сценариев; Claude Haiku для извлечения состояния и валидации.

### Обоснование
- Anthropic SDK предоставляет нативную async-поддержку для FastAPI
- Кэширование промптов встроено в API (снижение затрат 40-50% для повторяющихся системных промптов)
- Sonnet 4 предлагает лучшее соотношение качество/цена для генерации нарратива
- Haiku в 10 раз дешевле и достаточен для задач извлечения JSON

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| OpenAI GPT-4 | Широко используется, хорошая документация | Нет кэширования промптов, выше стоимость | Оптимизация затрат — требование конституции |
| Локальная LLM (Llama) | Нет затрат на API | Требует GPU, нестабильное качество | Сложность инфраструктуры, проблемы качества |
| Claude через Bedrock | Интеграция с AWS | Дополнительный слой абстракции | Прямой SDK проще для MVP |

### Примечания по реализации
```python
# Паттерн кэширования промптов
from anthropic import Anthropic

client = Anthropic()

# Системный промпт с контролем кэша
system_prompt = {
    "type": "text",
    "text": scenario_context,  # Кэшируется
    "cache_control": {"type": "ephemeral"}
}

response = await client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=2048,
    system=[system_prompt],
    messages=conversation_history[-15:]  # Последние 15 сообщений
)
```

---

## 2. WebSocket-коммуникация реального времени

### Решение
Использовать FastAPI WebSocket с Redis pub/sub для трансляции на несколько инстансов.

### Обоснование
- FastAPI имеет нативную поддержку WebSocket с async-обработчиками
- Redis pub/sub обеспечивает горизонтальное масштабирование (несколько инстансов API)
- Каналы per-room изолируют игровые сессии
- Автоматическое переподключение через клиентскую логику

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| Socket.IO | Богатые функции, встроенные комнаты | Python-реализация менее зрелая | Нативный WebSocket проще |
| Server-Sent Events | Простой, односторонний | Нет двунаправленной коммуникации | Нужен ввод действий игрока |
| Pusher/Ably | Управляемый сервис | Стоимость, внешняя зависимость | Redis уже нужен для кэша |

### Примечания по реализации
```python
# WebSocket с Redis pub/sub
from fastapi import WebSocket
import redis.asyncio as redis

class ConnectionManager:
    def __init__(self):
        self.connections: dict[str, list[WebSocket]] = {}  # room_id -> connections
        self.redis = redis.from_url(settings.REDIS_URL)

    async def connect(self, room_id: str, websocket: WebSocket):
        await websocket.accept()
        self.connections.setdefault(room_id, []).append(websocket)

    async def broadcast_to_room(self, room_id: str, message: dict):
        # Публикация в Redis для доставки между инстансами
        await self.redis.publish(f"room:{room_id}", json.dumps(message))

    async def subscribe_loop(self, room_id: str):
        pubsub = self.redis.pubsub()
        await pubsub.subscribe(f"room:{room_id}")
        async for message in pubsub.listen():
            if message["type"] == "message":
                for ws in self.connections.get(room_id, []):
                    await ws.send_json(json.loads(message["data"]))
```

---

## 3. Паттерн извлечения состояния

### Решение
Использовать Claude Haiku со структурированным JSON-выводом для извлечения изменений состояния мира после каждого ответа мастера.

### Обоснование
- Haiku экономичен ($0.25/1M input, $1.25/1M output)
- Структурированный вывод обеспечивает надёжный парсинг JSON
- Извлекает: события, смену локации, требования бросков кубиков, завершение сцен
- Выполняется async после отправки ответа мастера (неблокирующий)

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| Regex/NLP парсинг | Нет затрат на API | Ненадёжен с естественным языком | AI-сгенерированный текст непредсказуем |
| Тот же вызов Sonnet | Один запрос | Медленнее, дороже | Haiku в 10 раз дешевле |
| Ручное обновление состояния | Предсказуемо | Требует строгого формата от DM | Убивает свободу нарратива |

### Примечания по реализации
```python
# Промпт извлечения состояния
STATE_EXTRACTION_PROMPT = """
Проанализируй последний ответ мастера и извлеки изменения состояния как JSON:
{
  "events_occurred": ["event_id", ...],
  "current_location": "location_id или null",
  "scene_completed": "scene_id или null",
  "dice_required": {
    "type": "d20",
    "modifier": 3,
    "dc": 14,
    "skill": "Внимательность"
  } или null,
  "flags_changed": {"flag_name": true/false, ...}
}
"""

async def extract_state(dm_response: str, context: dict) -> StateUpdate:
    response = await client.messages.create(
        model="claude-haiku-3-20240307",
        max_tokens=500,
        messages=[{"role": "user", "content": f"{context}\n\nОтвет мастера:\n{dm_response}"}],
        system=STATE_EXTRACTION_PROMPT
    )
    return StateUpdate.model_validate_json(response.content[0].text)
```

---

## 4. Аутентификация с Sign in with Apple

### Решение
Использовать PyJWT для обработки токенов; верифицировать Apple identity-токены через эндпоинт публичных ключей Apple.

### Обоснование
- App Store требует Sign in with Apple, если предлагается любой социальный логин
- Apple предоставляет JWKS эндпоинт для верификации токенов
- JWT-токены для управления сессией (7-дневный access, 30-дневный refresh)

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| Firebase Auth | Обрабатывает Apple Sign In | Внешняя зависимость, привязка | Прямая верификация проста |
| Auth0 | Полнофункциональный | Стоимость, избыточен для MVP | Прямой JWT достаточен |
| Session cookies | Проще | Сложнее для мобильных клиентов | JWT — стандарт для мобильных |

### Примечания по реализации
```python
# Верификация Apple Sign In
import httpx
from jose import jwt

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"

async def verify_apple_token(identity_token: str) -> dict:
    async with httpx.AsyncClient() as client:
        keys_response = await client.get(APPLE_KEYS_URL)
        apple_keys = keys_response.json()["keys"]

    # Декодируем заголовок для получения kid
    header = jwt.get_unverified_header(identity_token)
    key = next(k for k in apple_keys if k["kid"] == header["kid"])

    # Верификация и декодирование
    payload = jwt.decode(
        identity_token,
        key,
        algorithms=["RS256"],
        audience=settings.APPLE_CLIENT_ID,
        issuer="https://appleid.apple.com"
    )
    return payload  # Содержит sub (user ID), email
```

---

## 5. JSON-схема сценария и валидация

### Решение
Хранить сценарии как JSONB в PostgreSQL; валидировать Pydantic-моделями; проверять логическую согласованность (достижимые акты, определённые ссылки на NPC).

### Обоснование
- JSONB позволяет гибкую эволюцию схемы
- Pydantic предоставляет runtime-валидацию с понятными сообщениями об ошибках
- Логическая валидация ловит ошибки AI-генерации на раннем этапе

### Схема сценария
```python
from pydantic import BaseModel
from typing import Literal

class Scene(BaseModel):
    id: str
    mandatory: bool
    description_for_ai: str
    dm_hints: list[str]
    possible_outcomes: list[str]

class Act(BaseModel):
    id: str
    entry_condition: str  # "session_start" или "flags.X === true"
    exit_conditions: list[str]
    scenes: list[Scene]

class NPC(BaseModel):
    id: str
    name: str
    role: Literal["ally", "enemy", "neutral"]
    personality: str
    speech_style: str
    secrets: list[str]
    motivation: str

class Location(BaseModel):
    id: str
    name: str
    atmosphere: str
    rooms: list[dict]  # Вложенная структура комнат

class Scenario(BaseModel):
    id: str
    title: str
    tone: Literal["dark_fantasy", "heroic", "horror", "mystery"]
    difficulty: Literal["beginner", "intermediate", "hardcore"]
    players_min: int = 2
    players_max: int = 5
    world_lore: str
    acts: list[Act]
    npcs: list[NPC]
    locations: list[Location]
    world_state: dict

def validate_scenario_logic(scenario: Scenario) -> list[str]:
    errors = []
    npc_ids = {npc.id for npc in scenario.npcs}
    location_ids = {loc.id for loc in scenario.locations}

    # Проверка ссылок на NPC в сценах
    for act in scenario.acts:
        for scene in act.scenes:
            # Извлечение упоминаний NPC из dm_hints
            # Проверка против npc_ids
            pass

    # Проверка достижимости актов
    # ... логика обхода графа

    return errors
```

---

## 6. Валидация персонажей D&D 5e

### Решение
Реализовать правила валидации как чистые функции; использовать SRD (System Reference Document) для данных классов/рас.

### Обоснование
- SRD свободен для использования по лицензии OGL
- Валидация обеспечивает честный геймплей
- Чистые функции легко тестировать

### Примечания по реализации
```python
# Валидация характеристик D&D 5e
DND_CLASSES = {
    "fighter": {"hit_die": "d10", "primary_ability": ["strength", "constitution"]},
    "wizard": {"hit_die": "d6", "primary_ability": ["intelligence"]},
    # ... все 12 базовых классов
}

DND_RACES = {
    "human": {"ability_bonuses": {"all": 1}},
    "elf": {"ability_bonuses": {"dexterity": 2}, "speed": 30},
    # ... все базовые расы
}

def validate_ability_scores(scores: dict[str, int]) -> list[str]:
    errors = []
    required = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]

    for ability in required:
        if ability not in scores:
            errors.append(f"Отсутствует характеристика: {ability}")
        elif not 1 <= scores[ability] <= 20:
            errors.append(f"{ability} должна быть от 1 до 20")

    # Валидация стандартного набора или покупки очками
    total = sum(scores.values())
    if total < 60 or total > 90:  # Разумные границы
        errors.append(f"Сумма характеристик ({total}) вне допустимого диапазона")

    return errors

def calculate_modifier(score: int) -> int:
    return (score - 10) // 2
```

---

## 7. Стратегия миграций базы данных

### Решение
Использовать Alembic с SQLAlchemy для миграций; автогенерация из изменений моделей.

### Обоснование
- Alembic — стандарт для проектов FastAPI/SQLAlchemy
- Автогенерация ускоряет разработку
- Контроль версий для изменений схемы

### Примечания по реализации
```bash
# Инициализация Alembic
alembic init alembic

# Генерация миграции из изменений модели
alembic revision --autogenerate -m "add characters table"

# Применение миграций
alembic upgrade head
```

---

## 8. Стратегия Rate Limiting

### Решение
Использовать slowapi (FastAPI rate limiter) с Redis-бэкендом; 60 запросов/минуту для REST, без лимита для WebSocket-сообщений.

### Обоснование
- Предотвращает злоупотребление и управляет затратами на AI
- Redis-бэкенд разделяет состояние между инстансами
- WebSocket-сообщения уже ограничены временем ответа AI

### Примечания по реализации
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=settings.REDIS_URL
)

@app.get("/scenarios")
@limiter.limit("60/minute")
async def list_scenarios(request: Request):
    ...
```

---

## Сводка ключевых решений

| Область | Решение | Ключевое преимущество |
|---------|---------|----------------------|
| AI-провайдер | Anthropic Claude (Sonnet + Haiku) | Кэширование промптов, оптимизация затрат |
| Реальное время | WebSocket + Redis pub/sub | Горизонтальное масштабирование |
| Извлечение состояния | Haiku с JSON-выводом | В 10 раз дешевле Sonnet |
| Аутентификация | JWT + верификация Apple Sign In | Дружественно к мобильным, совместимо с App Store |
| База данных | PostgreSQL + JSONB для сценариев | Гибкая схема, история версий |
| Валидация | Pydantic + правила D&D 5e | Типобезопасность, честный геймплей |
| Миграции | Alembic | Контроль версий схемы |
| Rate Limiting | slowapi + Redis | Предотвращение злоупотреблений |
