# Модель данных: Backend API AI Dungeon Master

**Функция**: 002-backend-api
**Дата**: 2026-02-21

## Диаграмма связей сущностей

```
┌─────────────┐       ┌─────────────────┐
│    User     │──────<│    Character    │
└─────────────┘       └─────────────────┘
       │                      │
       │                      │
       ▼                      │
┌─────────────┐               │
│  Scenario   │               │
└─────────────┘               │
       │                      │
       ▼                      │
┌─────────────────┐           │
│ ScenarioVersion │           │
└─────────────────┘           │
       │                      │
       ▼                      ▼
┌─────────────┐       ┌─────────────────┐
│    Room     │──────<│   RoomPlayer    │
└─────────────┘       └─────────────────┘
       │
       ▼
┌─────────────┐
│ GameSession │
└─────────────┘
       │
       ▼
┌─────────────────┐
│ SessionMessage  │
└─────────────────┘
```

## Сущности

### User

Владелец аккаунта с учётными данными аутентификации и профилем.

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| email | String(255) | UNIQUE, NOT NULL | Email пользователя |
| password_hash | String(255) | NULL | Хэш пароля (null для Apple Sign In) |
| apple_user_id | String(255) | UNIQUE, NULL | Идентификатор пользователя Apple Sign In |
| name | String(100) | NOT NULL | Отображаемое имя |
| avatar_url | String(500) | NULL | URL аватара |
| created_at | Timestamp | NOT NULL, DEFAULT NOW | Время создания аккаунта |
| updated_at | Timestamp | NOT NULL | Последнее обновление профиля |

**Правила валидации**:
- Email должен быть валидного формата
- Имя должно быть 2-100 символов
- Должен присутствовать либо password_hash, либо apple_user_id

**Индексы**:
- `idx_users_email` по email
- `idx_users_apple_user_id` по apple_user_id

---

### Character

D&D 5e игровой персонаж с атрибутами и предысторией.

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| user_id | UUID | FK → User.id, NOT NULL | Владелец |
| name | String(100) | NOT NULL | Имя персонажа |
| class | String(50) | NOT NULL | D&D класс (воин, волшебник и т.д.) |
| race | String(50) | NOT NULL | D&D раса (человек, эльф и т.д.) |
| level | Integer | NOT NULL, DEFAULT 1 | Уровень персонажа (1-20) |
| ability_scores | JSONB | NOT NULL | {strength, dexterity, constitution, intelligence, wisdom, charisma} |
| backstory | Text | NULL | Предыстория персонажа |
| created_at | Timestamp | NOT NULL, DEFAULT NOW | Время создания |
| updated_at | Timestamp | NOT NULL | Последнее обновление |

**Правила валидации**:
- Класс должен быть валидным классом D&D 5e
- Раса должна быть валидной расой D&D 5e
- Уровень должен быть 1-20
- Каждая характеристика должна быть 1-20
- Все шесть характеристик должны присутствовать

**JSONB-схема (ability_scores)**:
```json
{
  "strength": 15,
  "dexterity": 14,
  "constitution": 13,
  "intelligence": 12,
  "wisdom": 10,
  "charisma": 8
}
```

**Индексы**:
- `idx_characters_user_id` по user_id

---

### Scenario

Шаблон приключения, созданный пользователем, управляемый с версиями.

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| creator_id | UUID | FK → User.id, NOT NULL | Создатель |
| title | String(200) | NOT NULL | Название сценария |
| status | Enum | NOT NULL, DEFAULT 'draft' | draft, published, archived |
| current_version_id | UUID | FK → ScenarioVersion.id, NULL | Активная версия |
| created_at | Timestamp | NOT NULL, DEFAULT NOW | Время создания |
| updated_at | Timestamp | NOT NULL | Последнее обновление |

**Переходы статусов**:
- draft → published (при применении к комнате)
- published → archived (по действию пользователя)
- archived → published (восстановление)

**Индексы**:
- `idx_scenarios_creator_id` по creator_id
- `idx_scenarios_status` по status

---

### ScenarioVersion

Неизменяемый снимок контента сценария в определённый момент времени.

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| scenario_id | UUID | FK → Scenario.id, NOT NULL | Родительский сценарий |
| version | Integer | NOT NULL | Номер версии (1, 2, 3, ...) |
| content | JSONB | NOT NULL | Полная структура сценария |
| user_prompt | Text | NOT NULL | Промпт, создавший/изменивший эту версию |
| validation_errors | JSONB | NULL | Список проблем валидации (если есть) |
| created_at | Timestamp | NOT NULL, DEFAULT NOW | Время создания |

**JSONB-схема (content)**:
```json
{
  "tone": "dark_fantasy",
  "difficulty": "intermediate",
  "players_min": 2,
  "players_max": 5,
  "world_lore": "...",
  "acts": [
    {
      "id": "act_1",
      "entry_condition": "session_start",
      "exit_conditions": ["flag_a_triggered"],
      "scenes": [
        {
          "id": "scene_1",
          "mandatory": true,
          "description_for_ai": "...",
          "dm_hints": ["..."],
          "possible_outcomes": ["fight", "negotiate"]
        }
      ]
    }
  ],
  "npcs": [
    {
      "id": "npc_1",
      "name": "...",
      "role": "ally",
      "personality": "...",
      "speech_style": "...",
      "secrets": [],
      "motivation": "..."
    }
  ],
  "locations": [
    {
      "id": "loc_1",
      "name": "...",
      "atmosphere": "...",
      "rooms": []
    }
  ],
  "world_state": {
    "current_act": "act_1",
    "completed_scenes": [],
    "flags": {}
  }
}
```

**Индексы**:
- `idx_scenario_versions_scenario_id` по scenario_id
- `idx_scenario_versions_scenario_version` по (scenario_id, version) UNIQUE

---

### Room

Игровое лобби для координации мультиплеерной сессии.

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| host_id | UUID | FK → User.id, NOT NULL | Создатель/хост комнаты |
| scenario_version_id | UUID | FK → ScenarioVersion.id, NOT NULL | Выбранная версия сценария |
| name | String(100) | NOT NULL | Отображаемое имя комнаты |
| status | Enum | NOT NULL, DEFAULT 'waiting' | waiting, active, completed |
| max_players | Integer | NOT NULL, DEFAULT 5 | Максимум игроков (2-5) |
| created_at | Timestamp | NOT NULL, DEFAULT NOW | Время создания |
| started_at | Timestamp | NULL | Когда игра началась |
| completed_at | Timestamp | NULL | Когда игра закончилась |

**Переходы статусов**:
- waiting → active (хост начинает игру)
- active → completed (игра заканчивается или хост закрывает)

**Правила валидации**:
- max_players должен быть 2-5

**Индексы**:
- `idx_rooms_host_id` по host_id
- `idx_rooms_status` по status

---

### RoomPlayer

Связь между комнатой и участвующими игроками.

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| room_id | UUID | FK → Room.id, NOT NULL | Родительская комната |
| user_id | UUID | FK → User.id, NOT NULL | Участвующий пользователь |
| character_id | UUID | FK → Character.id, NULL | Выбранный персонаж (null до выбора) |
| status | Enum | NOT NULL, DEFAULT 'pending' | pending, approved, ready, declined |
| is_host | Boolean | NOT NULL, DEFAULT FALSE | Является ли хостом комнаты |
| joined_at | Timestamp | NOT NULL, DEFAULT NOW | Время запроса на вступление |

**Переходы статусов**:
- pending → approved (хост принимает) или declined (хост отклоняет)
- approved → ready (игрок отмечает готовность)
- ready → approved (игрок снимает готовность)

**Ограничения**:
- UNIQUE(room_id, user_id)

**Индексы**:
- `idx_room_players_room_id` по room_id
- `idx_room_players_user_id` по user_id

---

### GameSession

Активный экземпляр игры с состоянием мира.

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| room_id | UUID | FK → Room.id, UNIQUE, NOT NULL | Связанная комната |
| world_state | JSONB | NOT NULL | Текущее состояние игры |
| started_at | Timestamp | NOT NULL, DEFAULT NOW | Время начала сессии |
| ended_at | Timestamp | NULL | Время окончания сессии |

**JSONB-схема (world_state)**:
```json
{
  "current_act": "act_1",
  "current_scene": "scene_1",
  "current_location": "loc_1",
  "completed_scenes": ["intro_scene"],
  "flags": {
    "met_tavern_keeper": true,
    "discovered_secret_passage": false
  },
  "combat_active": false,
  "turn_order": []
}
```

**Индексы**:
- `idx_game_sessions_room_id` по room_id (UNIQUE)

---

### SessionMessage

Индивидуальное сообщение в игровой сессии (действие игрока или ответ мастера).

| Поле | Тип | Ограничения | Описание |
|------|-----|-------------|----------|
| id | UUID | PK | Уникальный идентификатор |
| session_id | UUID | FK → GameSession.id, NOT NULL | Родительская сессия |
| author_id | UUID | FK → User.id, NULL | Игрок, отправивший (null для DM) |
| role | Enum | NOT NULL | player, dm, system |
| content | Text | NOT NULL | Содержимое сообщения |
| dice_result | JSONB | NULL | Результат броска кубика, если применимо |
| state_delta | JSONB | NULL | Изменения состояния, извлечённые из ответа DM |
| created_at | Timestamp | NOT NULL, DEFAULT NOW | Время сообщения |

**JSONB-схема (dice_result)**:
```json
{
  "type": "d20",
  "base_roll": 15,
  "modifier": 3,
  "total": 18,
  "dc": 14,
  "skill": "Внимательность",
  "success": true
}
```

**JSONB-схема (state_delta)**:
```json
{
  "events_occurred": ["npc_rescued"],
  "location_changed": "tavern",
  "scene_completed": "rescue_scene",
  "flags_changed": {"npc_rescued": true}
}
```

**Индексы**:
- `idx_session_messages_session_id` по session_id
- `idx_session_messages_created_at` по created_at

---

## Структуры данных Redis

### Кэш состояния сессии

Быстрый доступ к текущему состоянию игры во время сессии.

**Ключ**: `session:{session_id}:state`
**Тип**: Hash
**TTL**: 24 часа

```
HSET session:abc123:state
  current_act "act_1"
  current_scene "scene_1"
  current_location "loc_1"
  flags '{"met_keeper":true}'
```

### Соединения комнаты

Отслеживание активных WebSocket-соединений по комнатам.

**Ключ**: `room:{room_id}:connections`
**Тип**: Set
**TTL**: Нет (управляется жизненным циклом соединения)

```
SADD room:xyz789:connections user_id_1 user_id_2
```

### Каналы Pub/Sub

Трансляция сообщений в реальном времени.

**Канал**: `room:{room_id}`
**Формат сообщения**: JSON

```json
{
  "type": "dm_response",
  "content": "...",
  "dice_required": null,
  "state_delta": {...}
}
```

---

## Заметки по миграциям

### Начальная миграция (001)
Создание всех таблиц с правильными внешними ключами и индексами.

### Будущие миграции
- Добавить `last_login_at` в User
- Добавить `experience_points` в Character (для прокачки)
- Добавить `is_public` в Scenario (для шаринга)
