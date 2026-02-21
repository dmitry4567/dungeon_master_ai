# Исследование: iOS-клиент AI Dungeon Master

**Функция**: 001-ios-client
**Дата**: 2026-02-21

## 1. Управление состоянием с Bloc/Cubit

### Решение
Использовать flutter_bloc с Cubit для простого состояния (авторизация, профиль) и полный Bloc для сложного событийно-ориентированного состояния (игровая сессия, создание персонажа).

### Обоснование
- Конституция требует паттерн Bloc/Cubit
- Cubit проще для потоков запрос/ответ (авторизация, CRUD)
- Полный Bloc с событиями лучше для сложной машины состояний игровой сессии
- Отличная поддержка тестирования через bloc_test

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| Riverpod | Современный, меньше шаблонного кода | Другая парадигма | Конституция указывает Bloc/Cubit |
| Provider | Простой | Нет событийно-ориентированного паттерна | Недостаточен для сложности игровой сессии |
| GetX | Минимум шаблонного кода | Менее структурированный | Не подходит для больших приложений |

### Примечания по реализации
```dart
// Cubit для простого состояния (авторизация)
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepository) : super(AuthInitial());

  Future<void> signInWithApple() async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signInWithApple();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}

// Полный Bloc для сложного состояния (игровая сессия)
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._sessionRepository) : super(SessionInitial()) {
    on<SessionStarted>(_onSessionStarted);
    on<PlayerActionSubmitted>(_onPlayerActionSubmitted);
    on<DiceRollRequested>(_onDiceRollRequested);
    on<DmResponseReceived>(_onDmResponseReceived);
  }
}
```

---

## 2. WebSocket-коммуникация

### Решение
Использовать пакет web_socket_channel с кастомной обёрткой WebSocketClient, которая обрабатывает переподключение, аутентификацию и парсинг сообщений.

### Обоснование
- Нативный Dart-пакет, не требуется платформо-специфичный код
- Поддерживает паттерны автоматического переподключения
- Хорошо интегрируется с Bloc через StreamSubscription

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| socket_io_client | Богатый функционал | Python-реализация менее зрелая | Нативный WebSocket проще |
| Dart IO WebSocket | Встроенный | Менее удобный API | web_socket_channel предпочтительнее |

### Примечания по реализации
```dart
class WebSocketClient {
  WebSocketChannel? _channel;
  final _messageController = StreamController<ServerMessage>.broadcast();
  Stream<ServerMessage> get messages => _messageController.stream;

  Future<void> connect(String sessionId, String token) async {
    final uri = Uri.parse('$baseWsUrl/sessions/$sessionId?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        final message = ServerMessage.fromJson(jsonDecode(data));
        _messageController.add(message);
      },
      onDone: _handleDisconnect,
      onError: _handleError,
    );
  }

  void sendAction(String content) {
    _channel?.sink.add(jsonEncode({
      'type': 'player_action',
      'content': content,
    }));
  }

  void sendDiceRoll(DiceResult result) {
    _channel?.sink.add(jsonEncode({
      'type': 'dice_roll',
      'result': result.toJson(),
    }));
  }
}
```

---

## 3. Голос на устройстве: TTS и STT

### Решение
Использовать flutter_tts для синтеза речи и speech_to_text для распознавания речи. Оба работают на устройстве для MVP (нулевые затраты на API).

### Обоснование
- Обработка на устройстве = без задержек, без затрат
- iOS имеет отличные встроенные речевые движки
- flutter_tts поддерживает русский через системные голоса iOS
- speech_to_text использует Apple Speech framework

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| OpenAI TTS API | Лучшее качество | Затраты, задержка | Премиум-функция после MVP |
| ElevenLabs | Кастомный голос | Высокие затраты | Премиум-функция после MVP |
| Whisper API | Лучшая точность | Затраты, задержка | На устройстве достаточно для MVP |

### Примечания по реализации
```dart
// Сервис TTS
class TtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}

// Сервис STT
class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;

  Future<bool> init() async {
    return await _stt.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
  }

  Future<void> startListening(Function(String) onResult) async {
    if (!_isListening) {
      _isListening = true;
      await _stt.listen(
        onResult: (result) => onResult(result.recognizedWords),
        localeId: 'ru_RU',
        listenFor: const Duration(seconds: 30),
      );
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _stt.stop();
  }
}
```

---

## 4. Стратегия локального хранения

### Решение
Использовать Isar для кэширования структурированных данных (персонажи, сценарии) и flutter_secure_storage для чувствительных данных (JWT-токены).

### Обоснование
- Isar быстрый, типобезопасный, поддерживает сложные запросы
- flutter_secure_storage использует iOS Keychain для токенов
- Разделение ответственности: кэш vs секреты

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| Hive | Популярный, быстрый | Менее типобезопасный | Isar более современный |
| sqflite | Знакомый SQL | Больше шаблонного кода | Isar проще для Flutter |
| SharedPreferences | Простой | Не для структурированных данных | Только для простых настроек |

### Примечания по реализации
```dart
// Isar для локального кэша
@collection
class CachedCharacter {
  Id get isarId => fastHash(id);

  final String id;
  final String name;
  final String characterClass;
  final String race;
  final Map<String, int> abilityScores;
  final DateTime cachedAt;
}

// Безопасное хранилище для токенов
class SecureTokenStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }
}
```

---

## 5. Анимация броска кубиков

### Решение
Использовать Lottie-анимации для бросков кубиков с физическим ощущением. Пререндерить несколько вариаций для каждого типа кубика.

### Обоснование
- Lottie обеспечивает плавные анимации 60fps
- Пререндеренные анимации гарантируют постоянное качество
- Несколько вариаций предотвращают ощущение повторяемости

### Рассмотренные альтернативы
| Вариант | Плюсы | Минусы | Отвергнут, потому что |
|---------|-------|--------|----------------------|
| Кастомные Flutter-анимации | Полный контроль | Время разработки | Lottie быстрее реализовать |
| 3D-рендеринг (flame) | Реалистичный | Производительность, сложность | Избыточно для MVP |
| Статические изображения | Просто | Скучный UX | Игроки D&D ожидают весёлые броски кубиков |

### Примечания по реализации
```dart
class DiceRoller extends StatefulWidget {
  final DiceRequest request;
  final Function(DiceResult) onRollComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${request.skill} Проверка (СЛ ${request.dc})'),
        GestureDetector(
          onTap: _rollDice,
          child: Lottie.asset(
            _getDiceAnimation(request.type),
            controller: _animationController,
            onLoaded: (composition) {
              _animationController.duration = composition.duration;
            },
          ),
        ),
        if (_result != null)
          Text('${_result!.total} (${_result!.baseRoll} + ${_result!.modifier})'),
      ],
    );
  }

  String _getDiceAnimation(String type) {
    return 'assets/animations/dice_$type.json';
  }
}
```

---

## 6. Навигация с go_router

### Решение
Использовать go_router с декларативной маршрутизацией, поддержкой глубоких ссылок и охранниками маршрутов для авторизации.

### Обоснование
- Конституция требует go_router
- Поддерживает глубокие ссылки (FR-002)
- Охранники маршрутов обрабатывают редирект авторизации
- Хорошо интегрируется с Bloc

### Примечания по реализации
```dart
final router = GoRouter(
  initialLocation: '/auth',
  redirect: (context, state) {
    final authState = context.read<AuthCubit>().state;
    final isAuth = authState is AuthAuthenticated;
    final isAuthRoute = state.matchedLocation == '/auth';

    if (!isAuth && !isAuthRoute) return '/auth';
    if (isAuth && isAuthRoute) return '/play';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/play', builder: ...),
        GoRoute(path: '/scenarios', builder: ...),
        GoRoute(path: '/characters', builder: ...),
        GoRoute(path: '/profile', builder: ...),
      ],
    ),
    GoRoute(
      path: '/session/:sessionId',
      builder: (context, state) => GameSessionPage(
        sessionId: state.pathParameters['sessionId']!,
      ),
    ),
    GoRoute(
      path: '/room/:roomId',
      builder: (context, state) => WaitingRoomPage(
        roomId: state.pathParameters['roomId']!,
      ),
    ),
  ],
);
```

---

## 7. Логика создания персонажа D&D 5e

### Решение
Реализовать клиентскую валидацию для создания персонажа, используя данные SRD (System Reference Document). Сервер валидирует повторно при сохранении.

### Обоснование
- Обратная связь в реальном времени при создании персонажа
- Данные SRD свободно доступны по лицензии OGL
- Двойная валидация (клиент + сервер) обеспечивает согласованность

### Примечания по реализации
```dart
// Классы D&D 5e
const dndClasses = {
  'barbarian': DndClass(
    name: 'Варвар',
    hitDie: 'd12',
    primaryAbilities: ['strength'],
    savingThrows: ['strength', 'constitution'],
    armorProficiencies: ['light', 'medium', 'shields'],
  ),
  'wizard': DndClass(
    name: 'Волшебник',
    hitDie: 'd6',
    primaryAbilities: ['intelligence'],
    savingThrows: ['intelligence', 'wisdom'],
    armorProficiencies: [],
  ),
  // ... все 12 базовых классов
};

// Расчёт модификатора характеристики
int calculateModifier(int score) => (score - 10) ~/ 2;

// Валидация характеристик (стандартный набор или покупка очками)
bool validateAbilityScores(Map<String, int> scores) {
  final values = scores.values.toList();
  if (values.length != 6) return false;
  if (values.any((v) => v < 1 || v > 20)) return false;

  final total = values.reduce((a, b) => a + b);
  return total >= 60 && total <= 90; // Разумные границы
}
```

---

## 8. Тема и визуальный стиль

### Решение
Тёмная тема как основная с дизайн-языком фэнтези/средневековья. Кастомная цветовая палитра, вдохновлённая эстетикой D&D.

### Обоснование
- Тёмная тема снижает нагрузку на глаза при длительных игровых сессиях
- Фэнтезийная эстетика соответствует ожиданиям бренда D&D
- Конституция указывает тёмную тему как основную

### Примечания по реализации
```dart
class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF8B4513), // Коричневый седла
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFD4AF37),      // Золотой
      secondary: Color(0xFF8B0000),    // Тёмно-красный
      surface: Color(0xFF16213E),
      background: Color(0xFF1A1A2E),
      error: Color(0xFFCF6679),
    ),
    textTheme: GoogleFonts.cinzelTextTheme(
      ThemeData.dark().textTheme,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}
```

---

## Сводка ключевых решений

| Область | Решение | Ключевое преимущество |
|---------|---------|----------------------|
| Управление состоянием | Bloc/Cubit по конституции | Тестируемость, масштабируемость |
| WebSocket | web_socket_channel + обёртка | Простота, надёжность |
| Голос | flutter_tts + speech_to_text на устройстве | Нулевые затраты, низкая задержка |
| Локальное хранение | Isar + flutter_secure_storage | Быстрый кэш, безопасные токены |
| Анимация кубиков | Lottie | Плавные 60fps, весёлый UX |
| Навигация | go_router | Глубокие ссылки, охранники авторизации |
| Логика D&D | Клиентская валидация SRD | Обратная связь в реальном времени |
| Тема | Тёмная фэнтезийная эстетика | Соответствует бренду D&D |
