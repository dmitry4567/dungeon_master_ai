# План реализации: iOS-клиент AI Dungeon Master

**Ветка**: `001-ios-client` | **Дата**: 2026-02-21 | **Спецификация**: [spec.md](./spec.md)
**Вводные данные**: Спецификация функции из `/specs/001-ios-client/spec.md`

## Краткое описание

Flutter iOS-клиент, предоставляющий пользовательский интерфейс для AI Dungeon Master — ролевой игры D&D 5e с AI в роли мастера. Приложение включает интерфейс чата игровой сессии с голосовым вводом/выводом, конструктор сценариев с превью AI-генерации, мастер создания персонажа, мультиплеерное лобби и управление профилем пользователя. Вся бизнес-логика и оркестрация AI обрабатывается backend API (002-backend-api).

## Технический контекст

**Язык/Версия**: Dart 3.x / Flutter 3.x
**Основные зависимости**: flutter_bloc, get_it, injectable, freezed, go_router, dio, retrofit, web_socket_channel, flutter_tts, speech_to_text
**Хранилище**: Isar (локальный кэш), flutter_secure_storage (токены)
**Тестирование**: flutter_test, bloc_test, mockito, integration_test
**Целевая платформа**: iOS 15+ (iPhone)
**Тип проекта**: Мобильное приложение
**Цели производительности**: 60fps анимации, <3с холодный старт, <100МБ размер приложения
**Ограничения**: TTS/STT на устройстве для MVP, сеть требуется для игры, интерфейс на русском языке
**Масштаб/Объём**: ~15 экранов, 6 функциональных модулей, MVP одним разработчиком

## Проверка конституции

*КОНТРОЛЬНАЯ ТОЧКА: Должна пройти перед Фазой 0 исследования. Перепроверить после Фазы 1 проектирования.*

| Принцип | Статус | Примечания по реализации |
|---------|--------|--------------------------|
| I. AI только на бэкенде | ✅ ПРОЙДЕНО | Клиент НЕ делает AI-вызовов; всё через backend REST/WebSocket |
| II. Мультиплеер реального времени | ✅ ПРОЙДЕНО | WebSocket через web_socket_channel для игровых сессий |
| III. Безопасность контента | ✅ ПРОЙДЕНО | Модерация контента на бэкенде; клиент отображает отфильтрованные ответы |
| IV. Оптимизация затрат | ✅ ПРОЙДЕНО | Н/Д для клиента — затраты управляются на бэкенде |
| V. Разработка через тестирование | ✅ ПРОЙДЕНО | bloc_test для состояния, widget-тесты для UI, интеграционные тесты |
| VI. Правила D&D 5e | ✅ ПРОЙДЕНО | UI создания персонажа валидирует по правилам 5e; модификаторы бросков по 5e |

**Соответствие App Store (раздел конституции):**

| Требование | Статус | Примечания |
|------------|--------|------------|
| Sign in with Apple | ✅ | FR-004 требует основную кнопку авторизации Apple |
| Apple IAP | ⏳ ОТЛОЖЕНО | После MVP; архитектура поддерживает через purchases_flutter |
| NSMicrophoneUsageDescription | ✅ | Требуется для голосового ввода (FR-033) |
| NSSpeechRecognitionUsageDescription | ✅ | Требуется для STT (FR-034) |
| Политика конфиденциальности | ✅ | Ссылка на экране профиля/настроек |

**Процесс разработки (раздел конституции):**

| Требование | Статус | Примечания |
|------------|--------|------------|
| Паттерн Bloc/Cubit | ✅ | Каждая функция имеет выделенный Bloc/Cubit |
| Модульная структура lib/features/ | ✅ | См. Структуру проекта ниже |
| get_it + injectable | ✅ | Настройка DI в core/di/ |
| go_router | ✅ | Навигация в core/router/ |
| freezed + json_serializable | ✅ | Все модели используют freezed |

**Результат контрольной точки**: ПРОЙДЕНО — Все принципы и требования конституции удовлетворены.

## Структура проекта

### Документация (эта функция)

```text
specs/001-ios-client/
├── plan.md              # Этот файл
├── research.md          # Результат Фазы 0
├── data-model.md        # Результат Фазы 1
├── quickstart.md        # Результат Фазы 1
├── contracts/           # Н/Д (клиент потребляет backend API)
└── tasks.md             # Результат Фазы 2 (команда /speckit.tasks)
```

### Исходный код (корень репозитория)

```text
ios/
├── lib/
│   ├── main.dart
│   ├── app.dart                      # MaterialApp с go_router
│   ├── core/
│   │   ├── di/                       # Настройка get_it + injectable
│   │   │   ├── injection.dart
│   │   │   └── injection.config.dart
│   │   ├── network/
│   │   │   ├── api_client.dart       # Dio + Retrofit
│   │   │   ├── websocket_client.dart # Обёртка WebSocket
│   │   │   └── interceptors/
│   │   ├── router/
│   │   │   ├── app_router.dart       # Конфигурация go_router
│   │   │   └── routes.dart
│   │   ├── storage/
│   │   │   ├── secure_storage.dart   # JWT токены
│   │   │   └── local_database.dart   # Кэш Isar
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── colors.dart
│   │   │   └── typography.dart
│   │   └── utils/
│   │       ├── extensions.dart
│   │       └── constants.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── bloc/
│   │   │   │   ├── auth_bloc.dart
│   │   │   │   ├── auth_event.dart
│   │   │   │   └── auth_state.dart
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_api.dart
│   │   │   ├── models/
│   │   │   │   └── user.dart
│   │   │   └── ui/
│   │   │       ├── login_page.dart
│   │   │       └── widgets/
│   │   ├── character/
│   │   │   ├── bloc/
│   │   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── character.dart
│   │   │   │   ├── dnd_class.dart
│   │   │   │   └── dnd_race.dart
│   │   │   └── ui/
│   │   │       ├── character_list_page.dart
│   │   │       ├── character_create_page.dart
│   │   │       ├── character_detail_page.dart
│   │   │       └── widgets/
│   │   │           ├── class_selector.dart
│   │   │           ├── race_selector.dart
│   │   │           ├── ability_scores_editor.dart
│   │   │           └── character_card.dart
│   │   ├── scenario/
│   │   │   ├── bloc/
│   │   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── scenario.dart
│   │   │   │   ├── scenario_version.dart
│   │   │   │   ├── act.dart
│   │   │   │   ├── npc.dart
│   │   │   │   └── location.dart
│   │   │   └── ui/
│   │   │       ├── scenario_list_page.dart
│   │   │       ├── scenario_builder_page.dart
│   │   │       ├── scenario_preview_page.dart
│   │   │       └── widgets/
│   │   │           ├── scenario_card.dart
│   │   │           ├── act_expansion_tile.dart
│   │   │           ├── npc_card.dart
│   │   │           └── version_history_sheet.dart
│   │   ├── lobby/
│   │   │   ├── bloc/
│   │   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── room.dart
│   │   │   │   └── room_player.dart
│   │   │   └── ui/
│   │   │       ├── lobby_page.dart
│   │   │       ├── room_create_page.dart
│   │   │       ├── waiting_room_page.dart
│   │   │       └── widgets/
│   │   │           ├── room_card.dart
│   │   │           ├── player_avatar.dart
│   │   │           └── join_request_dialog.dart
│   │   ├── game_session/
│   │   │   ├── bloc/
│   │   │   │   ├── session_bloc.dart
│   │   │   │   ├── session_event.dart
│   │   │   │   └── session_state.dart
│   │   │   ├── data/
│   │   │   │   ├── session_repository.dart
│   │   │   │   └── websocket_handler.dart
│   │   │   ├── models/
│   │   │   │   ├── game_session.dart
│   │   │   │   ├── message.dart
│   │   │   │   ├── dice_request.dart
│   │   │   │   └── dice_result.dart
│   │   │   └── ui/
│   │   │       ├── game_session_page.dart
│   │   │       └── widgets/
│   │   │           ├── chat_message_list.dart
│   │   │           ├── chat_input_bar.dart
│   │   │           ├── dice_roller.dart
│   │   │           ├── voice_input_button.dart
│   │   │           └── dm_thinking_indicator.dart
│   │   └── profile/
│   │       ├── bloc/
│   │       ├── data/
│   │       ├── models/
│   │       └── ui/
│   │           ├── profile_page.dart
│   │           ├── settings_page.dart
│   │           └── widgets/
│   └── shared/
│       ├── widgets/
│       │   ├── loading_skeleton.dart
│       │   ├── error_view.dart
│       │   ├── offline_banner.dart
│       │   └── fantasy_button.dart
│       └── models/
│           └── api_error.dart
├── test/
│   ├── unit/
│   │   ├── character/
│   │   │   └── ability_scores_test.dart
│   │   └── game_session/
│   │       └── dice_calculation_test.dart
│   ├── bloc/
│   │   ├── auth_bloc_test.dart
│   │   ├── session_bloc_test.dart
│   │   └── character_bloc_test.dart
│   ├── widget/
│   │   ├── dice_roller_test.dart
│   │   └── character_card_test.dart
│   └── integration/
│       └── game_flow_test.dart
├── ios/
│   └── Runner/
│       └── Info.plist              # Разрешения
├── assets/
│   ├── images/
│   ├── icons/
│   ├── animations/                 # Lottie-файлы для кубиков
│   └── fonts/
├── pubspec.yaml
├── analysis_options.yaml
└── build.yaml                      # Конфигурация freezed, injectable
```

**Решение по структуре**: Мобильный проект с модульной архитектурой на основе функций согласно конституции. Каждая функция (auth, character, scenario, lobby, game_session, profile) имеет изолированные слои bloc, data, models и ui. Базовые утилиты общие для всех функций. Тесты повторяют структуру функций.

## Отслеживание сложности

> Нарушений конституции для обоснования нет.

| Нарушение | Почему необходимо | Простая альтернатива отвергнута, потому что |
|-----------|-------------------|---------------------------------------------|
| — | — | — |
