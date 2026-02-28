# Рекомендации по разработке dungeon_master_ai

Автоматически сгенерировано из всех планов функций. Последнее обновление: 2026-02-21

## Активные технологии
- Dart 3.x / Flutter 3.x + flutter_bloc, get_it, injectable, freezed, go_router, dio, retrofit, web_socket_channel, flutter_tts, speech_to_text (001-ios-client)
- Isar (локальный кэш), flutter_secure_storage (токены) (001-ios-client)

- Python 3.11+ + FastAPI, Anthropic SDK, SQLAlchemy, Pydantic, python-jose (JWT), websockets (002-backend-api)

## Структура проекта

```text
ios/                    # Flutter iOS-клиент
├── lib/
│   ├── core/           # Общая инфраструктура
│   ├── features/       # Функциональные модули
│   └── shared/         # Общие виджеты

backend/                # Python FastAPI бэкенд
├── src/
│   ├── api/            # Роуты и middleware
│   ├── models/         # SQLAlchemy модели
│   ├── services/       # Бизнес-логика
│   └── core/           # Конфигурация
└── tests/

specs/                  # Спецификации функций
├── 001-ios-client/
└── 002-backend-api/
```

## Команды

### iOS-клиент
```bash
cd ios
flutter pub get                                           # Установка зависимостей
flutter pub run build_runner build --delete-conflicting-outputs  # Генерация кода
flutter test                                              # Запуск тестов
flutter run -d ios                                        # Запуск на симуляторе
```

### Backend API
```bash
cd backend
pip install -e ".[dev]"     # Установка зависимостей
pytest                       # Запуск тестов
ruff check .                 # Линтинг
uvicorn src.api.main:app --reload  # Запуск сервера разработки
```

## Стиль кода

- **Python 3.11+**: Следовать стандартным конвенциям, использовать type hints
- **Dart/Flutter**: Использовать freezed для моделей, bloc/cubit для состояния

## Основные принципы

1. **AI только на бэкенде** — клиент не делает AI-вызовов напрямую
2. **Мультиплеер реального времени** — WebSocket + Redis pub/sub
3. **Оптимизация затрат** — кэширование промптов, Haiku для извлечения состояния
4. **D&D 5e** — валидация по правилам SRD
5. **Разработка через тестирование** — тесты для критической логики

## Последние изменения
- 001-ios-client: Добавлен Dart 3.x / Flutter 3.x + flutter_bloc, get_it, injectable, freezed, go_router, dio, retrofit, web_socket_channel, flutter_tts, speech_to_text

- 002-backend-api: Добавлен Python 3.11+ + FastAPI, Anthropic SDK, SQLAlchemy, Pydantic, python-jose (JWT), websockets

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

## Active Technologies
- Python 3.11+ (backend), Dart 3.x / Flutter 3.x (iOS client) + FastAPI + `agora-token>=2.0.0` (backend); `agora_rtc_engine ^6.3.0` + flutter_bloc (Flutter) (003-agora-voice-chat)
- PostgreSQL (существующий, без новых таблиц) + Agora инфраструктура (медиа) (003-agora-voice-chat)
- N/A (no persistent storage, runtime state only) (004-elevenlabs-tts-streaming)

## Recent Changes
- 003-agora-voice-chat: Added Python 3.11+ (backend), Dart 3.x / Flutter 3.x (iOS client) + FastAPI + `agora-token>=2.0.0` (backend); `agora_rtc_engine ^6.3.0` + flutter_bloc (Flutter)
