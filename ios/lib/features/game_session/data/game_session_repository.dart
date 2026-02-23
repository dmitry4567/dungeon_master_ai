import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/network/websocket_client.dart';
import '../../../core/storage/local_database.dart';
import '../models/message.dart';
import '../models/world_state.dart';
import 'game_session_api.dart';

/// Репозиторий для игровой сессии
@lazySingleton
class GameSessionRepository {
  GameSessionRepository(
    this._api,
    this._wsClient,
    this._localDatabase,
  );

  final GameSessionApi _api;
  final WebSocketClient _wsClient;
  final LocalDatabase _localDatabase;

  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  StreamSubscription<WebSocketState>? _connectionSubscription;

  final _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController =
      StreamController<WebSocketState>.broadcast();

  /// Поток типизированных WS-сообщений (type + data)
  Stream<Map<String, dynamic>> get messagesStream =>
      _messagesController.stream;

  /// Поток состояния соединения
  Stream<WebSocketState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Подключиться к сессии
  Future<void> connectToSession(String roomId) async {
    // Слушаем WS-сообщения
    _wsSubscription = _wsClient.messages.listen(_messagesController.add);

    // Слушаем состояние соединения
    _connectionSubscription = _wsClient.connectionState.listen(_connectionStateController.add);

    await _wsClient.connect(roomId);
  }

  /// Отключиться от сессии
  Future<void> disconnectFromSession() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _wsClient.disconnect();
  }

  /// Отправить сообщение игрока через WS
  void sendMessage(String content) {
    _wsClient.sendPlayerAction(content);
  }

  /// Отправить результат броска кубика
  void sendDiceRoll({
    required String requestId,
    required List<int> rolls,
  }) {
    _wsClient.sendDiceRollResult(requestId: requestId, rolls: rolls);
  }

  /// Получить сессию по roomId через REST
  Future<GameSession> getSessionByRoom(String roomId) async => _api.getSessionByRoom(roomId);

  /// Получить сообщения через REST
  Future<List<Message>> getMessages(String sessionId) async {
    try {
      final messages = await _api.getMessages(sessionId);
      // Кэшировать сообщения
      await _cacheMessages(sessionId, messages);
      return messages;
    } catch (e) {
      // При ошибке попробовать из кэша
      return _getCachedMessages(sessionId);
    }
  }

  /// Завершить сессию
  Future<void> endSession(String sessionId) async {
    await _api.endSession(sessionId);
  }

  /// Кэшировать сообщения в SQLite
  Future<void> _cacheMessages(
    String sessionId,
    List<Message> messages,
  ) async {
    try {
      final db = _localDatabase.database;
      final batch = db.batch();
      for (final msg in messages) {
        batch.insert(
          'cached_messages',
          {
            'id': msg.id,
            'room_id': sessionId,
            'data': jsonEncode(msg.toJson()),
            'created_at': msg.createdAt.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // Игнорируем ошибки кэширования
    }
  }

  /// Получить кэшированные сообщения
  Future<List<Message>> _getCachedMessages(String sessionId) async {
    try {
      final db = _localDatabase.database;
      final results = await db.query(
        'cached_messages',
        where: 'room_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at ASC',
      );
      return results
          .map((row) =>
              Message.fromJson(jsonDecode(row['data']! as String) as Map<String, dynamic>),)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Освободить ресурсы
  Future<void> dispose() async {
    await disconnectFromSession();
    await _messagesController.close();
    await _connectionStateController.close();
  }
}
