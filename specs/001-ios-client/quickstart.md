# Быстрый старт: iOS-клиент AI Dungeon Master

**Функция**: 001-ios-client
**Дата**: 2026-02-21

## Предварительные требования

- Flutter 3.x (стабильный канал)
- Dart 3.x
- Xcode 15+ (для сборки iOS)
- CocoaPods
- Запущенный Backend API (см. 002-backend-api)

## Установка

### 1. Клонирование и установка зависимостей

```bash
cd ios
flutter pub get
```

### 2. Генерация кода (freezed, injectable, json_serializable)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Настройка iOS

```bash
cd ios
pod install
cd ..
```

### 4. Конфигурация окружения

Создайте `lib/core/config/env.dart`:

```dart
class Env {
  static const String apiBaseUrl = 'http://localhost:8000/v1';
  static const String wsBaseUrl = 'ws://localhost:8000/v1';

  // Для продакшена используйте:
  // static const String apiBaseUrl = 'https://api.aidm.example.com/v1';
  // static const String wsBaseUrl = 'wss://api.aidm.example.com/v1';
}
```

### 5. Запуск приложения

```bash
# iOS Симулятор
flutter run -d ios

# Конкретное устройство
flutter devices
flutter run -d <device_id>
```

## Проверка установки

### Проверка работоспособности

1. Запустите приложение
2. Вы должны увидеть экран входа с кнопкой "Войти через Apple"
3. Если бэкенд запущен, зарегистрируйте тестовый аккаунт

### Создание персонажа

1. После входа перейдите на вкладку "Персонажи"
2. Нажмите "+" для создания нового персонажа
3. Пройдите мастер:
   - Выберите класс (например, Воин)
   - Выберите расу (например, Человек)
   - Назначьте характеристики
   - Напишите предысторию (опционально)
4. Сохраните персонажа

### Присоединение к игровой сессии

1. Перейдите на вкладку "Играть"
2. Создайте комнату или присоединитесь к существующей
3. Выберите своего персонажа
4. Отметьте готовность
5. Начните игру (если вы хост)
6. Отправьте тестовое действие: "Я осматриваюсь"
7. Убедитесь, что ответ мастера появился

## Запуск тестов

```bash
# Все тесты
flutter test

# Конкретный файл теста
flutter test test/bloc/session_bloc_test.dart

# С покрытием
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Интеграционные тесты (требуется устройство/симулятор)
flutter test integration_test/
```

## Структура проекта

```
ios/
├── lib/
│   ├── main.dart           # Точка входа
│   ├── app.dart            # MaterialApp + роутер
│   ├── core/               # Общая инфраструктура
│   │   ├── di/             # Внедрение зависимостей
│   │   ├── network/        # API + WebSocket клиенты
│   │   ├── router/         # Конфигурация go_router
│   │   ├── storage/        # Локальное хранилище
│   │   └── theme/          # Тема приложения
│   ├── features/           # Функциональные модули
│   │   ├── auth/
│   │   ├── character/
│   │   ├── scenario/
│   │   ├── lobby/
│   │   ├── game_session/
│   │   └── profile/
│   └── shared/             # Общие виджеты
├── test/                   # Тесты
├── ios/                    # Нативный код iOS
├── assets/                 # Изображения, шрифты, анимации
└── pubspec.yaml
```

## Типичные задачи

### Перегенерация кода после изменения моделей

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Добавление новой зависимости

```bash
flutter pub add <название_пакета>
flutter pub get
```

### Обновление всех зависимостей

```bash
flutter pub upgrade
```

### Чистая сборка

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
```

### Сборка для релиза

```bash
# Архив iOS
flutter build ios --release

# Открыть в Xcode для публикации в App Store
open ios/Runner.xcworkspace
```

## Ключевые файлы

| Файл | Назначение |
|------|------------|
| `lib/main.dart` | Точка входа, инициализация DI |
| `lib/app.dart` | MaterialApp, роутер, провайдеры |
| `lib/core/di/injection.dart` | Настройка get_it |
| `lib/core/network/api_client.dart` | Dio + Retrofit |
| `lib/core/network/websocket_client.dart` | Обработчик WebSocket |
| `lib/features/game_session/bloc/session_bloc.dart` | Состояние игровой сессии |
| `ios/Runner/Info.plist` | Разрешения iOS |
| `pubspec.yaml` | Зависимости |

## Разрешения iOS (Info.plist)

Необходимые записи уже настроены:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Используется для голосового управления в игре</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Используется для распознавания голосовых команд</string>
```

## Устранение неполадок

### "Устройства не найдены"

```bash
# Проверить подключённые устройства
flutter devices

# Открыть iOS Симулятор
open -a Simulator
```

### "CocoaPods не установлен"

```bash
sudo gem install cocoapods
```

### "Ошибка сборки с подписью кода"

1. Откройте `ios/Runner.xcworkspace` в Xcode
2. Выберите цель Runner
3. Установите вашу команду разработки в Signing & Capabilities

### "Ошибка подключения WebSocket"

- Убедитесь, что бэкенд запущен на правильном порту
- Проверьте, что `Env.wsBaseUrl` соответствует URL бэкенда
- Для симулятора используйте `localhost`; для устройства — IP компьютера

### "Распознавание речи не работает"

- Убедитесь, что разрешение на микрофон предоставлено
- Проверьте, что настройки языка устройства включают русский
- Тестируйте в тихом окружении

## Советы по разработке

### Горячая перезагрузка

Нажмите `r` в терминале во время работы `flutter run`.

### Горячий перезапуск

Нажмите `R` (заглавную) в терминале.

### Отладка состояний Bloc

Добавьте `BlocObserver`:

```dart
void main() {
  Bloc.observer = SimpleBlocObserver();
  runApp(const App());
}

class SimpleBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType} $change');
  }
}
```

### Просмотр сетевых запросов

Используйте интерцептор логирования `dio` (уже настроен в режиме отладки).
