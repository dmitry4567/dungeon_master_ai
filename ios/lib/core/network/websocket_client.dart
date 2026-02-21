import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

/// Клиент WebSocket для реального времени
@lazySingleton
class WebSocketClient {
  WebSocketClient(this._secureStorage);

  final SecureStorage _secureStorage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<WebSocketState>.broadcast();

  /// Поток входящих сообщений
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Поток состояния соединения
  Stream<WebSocketState> get connectionState => _connectionStateController.stream;

  /// Текущее состояние соединения
  WebSocketState _currentState = WebSocketState.disconnected;
  WebSocketState get currentState => _currentState;

  /// Количество попыток переподключения
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _reconnectDelay = Duration(seconds: 2);

  /// Подключиться к комнате
  Future<void> connect(String roomId) async {
    if (_currentState == WebSocketState.connected ||
        _currentState == WebSocketState.connecting) {
      return;
    }

    _updateState(WebSocketState.connecting);

    try {
      final accessToken = await _secureStorage.getAccessToken();
      if (accessToken == null) {
        _updateState(WebSocketState.error);
        return;
      }

      final wsUrl = '${AppConfig.current.wsBaseUrl}/rooms/$roomId?token=$accessToken';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await _channel!.ready;

      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: () => _onDone(roomId),
        cancelOnError: false,
      );
    } catch (e) {
      _updateState(WebSocketState.error);
      _scheduleReconnect(roomId);
    }
  }

  /// Отключиться
  Future<void> disconnect() async {
    _reconnectAttempts = _maxReconnectAttempts; // Предотвращаем переподключение
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _updateState(WebSocketState.disconnected);
  }

  /// Отправить сообщение
  void send(Map<String, dynamic> message) {
    if (_currentState != WebSocketState.connected || _channel == null) {
      return;
    }

    _channel!.sink.add(jsonEncode(message));
  }

  /// Отправить действие игрока
  void sendPlayerAction(String action) {
    send({
      'type': 'player_action',
      'payload': {'action': action},
    });
  }

  /// Отправить бросок кубиков
  void sendDiceRoll({
    required String diceType,
    required int count,
    int modifier = 0,
  }) {
    send({
      'type': 'dice_roll',
      'payload': {
        'dice_type': diceType,
        'count': count,
        'modifier': modifier,
      },
    });
  }

  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      _messageController.add(message);
    } catch (e) {
      // Игнорируем некорректные сообщения
    }
  }

  void _onError(Object error) {
    _updateState(WebSocketState.error);
  }

  void _onDone(String roomId) {
    _updateState(WebSocketState.disconnected);
    _scheduleReconnect(roomId);
  }

  void _scheduleReconnect(String roomId) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _updateState(WebSocketState.error);
      return;
    }

    _reconnectAttempts++;
    _updateState(WebSocketState.reconnecting);

    Future.delayed(
      _reconnectDelay * _reconnectAttempts,
      () => connect(roomId),
    );
  }

  void _updateState(WebSocketState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Освободить ресурсы
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionStateController.close();
  }
}

/// Состояние WebSocket соединения
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}
