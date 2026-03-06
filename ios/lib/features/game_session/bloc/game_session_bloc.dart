import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/websocket_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../scenario/models/scenario_content.dart';
import '../data/game_session_repository.dart';
import '../models/dice_result.dart';
import '../models/message.dart';
import '../models/world_state.dart';
import 'game_session_event.dart';
import 'game_session_state.dart';

@injectable
class GameSessionBloc extends Bloc<GameSessionEvent, GameSessionState> {
  GameSessionBloc(this._repository, this._secureStorage)
      : super(const GameSessionState.initial()) {
    on<ConnectToSessionEvent>(_onConnectToSession);
    on<SendMessageEvent>(_onSendMessage);
    on<MessageReceivedEvent>(_onMessageReceived);
    on<ConnectionStateChangedEvent>(_onConnectionStateChanged);
    on<EndSessionEvent>(_onEndSession);
    on<LeaveSessionEvent>(_onLeaveSession);
    on<RollDiceEvent>(_onRollDice);
    on<MarkMessageRolledEvent>(_onMarkMessageRolled);
  }

  final GameSessionRepository _repository;
  final SecureStorage _secureStorage;
  String? _currentUserId;

  StreamSubscription<Map<String, dynamic>>? _messagesSubscription;
  StreamSubscription<WebSocketState>? _connectionSubscription;

  Future<void> _onConnectToSession(
    ConnectToSessionEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    emit(const GameSessionState.connecting());

    try {
      // 1. Загрузить сессию по ID комнаты
      final session = await _repository.getSessionByRoom(event.roomId);

      // 2. Параллельно загрузить остальное, используя session.id
      final results = await Future.wait([
        _repository.getMessages(session.id),
        _repository.getScenarioContent(session.id),
        _secureStorage.getUserId(),
      ]);

      final messages = results[0]! as List<Message>;
      final scenarioContent = results[1]! as ScenarioContent;
      _currentUserId = results[2] as String?;

      final isHost = _currentUserId != null; // Упрощённо, TODO: проверить через room

      // Подписаться на WS-события
      _messagesSubscription = _repository.messagesStream.listen((message) {
        final type = message['type'] as String? ?? '';
        add(GameSessionEvent.messageReceived(type: type, data: message));
      });

      _connectionSubscription =
          _repository.connectionStateStream.listen((wsState) {
        add(GameSessionEvent.connectionStateChanged(state: wsState.name));
      });

      // Подключить WS
      await _repository.connectToSession(event.roomId);

      emit(GameSessionState.active(
        sessionId: session.id,
        roomId: event.roomId,
        messages: messages,
        worldState: session.worldState,
        scenarioContent: scenarioContent,
        isHost: isHost,
      ),);
    } catch (e) {
      emit(GameSessionState.error(
        message: 'Не удалось подключиться к сессии: $e',
      ),);
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GameSessionActive) return;

    final userId = await _secureStorage.getUserId();

    // Оптимистично добавить сообщение игрока
    final playerMessage = Message(
      id: const Uuid().v4(),
      authorId: userId,
      role: MessageRole.player,
      content: event.content,
      createdAt: DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, playerMessage],
    ),);

    // Отправить через WS
    _repository.sendMessage(event.content);
  }

  Future<void> _onMessageReceived(
    MessageReceivedEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GameSessionActive) return;

    switch (event.type) {
      case 'player_broadcast':
        _handlePlayerBroadcast(currentState, event.data, emit);
      case 'dm_response_chunk':
        _handleDmResponseChunk(currentState, event.data, emit);
      case 'dm_response_end':
        _handleDmResponseEnd(currentState, event.data, emit);
      case 'dice_result':
        _handleDiceResult(currentState, event.data, emit);
      case 'state_update':
        _handleStateUpdate(currentState, event.data, emit);
      case 'player_join':
        _handlePlayerJoin(currentState, event.data, emit);
      case 'player_leave':
        _handlePlayerLeave(currentState, event.data, emit);
      case 'error':
        _handleError(currentState, event.data, emit);
      case 'system_message':
        _handleSystemMessage(currentState, event.data, emit);
      case 'dice_request':
        _handleDiceRequest(currentState, event.data, emit);
      case 'voice_channel_closed':
        _handleVoiceChannelClosed(currentState, emit);
    }
  }

  void _handlePlayerBroadcast(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final messageId = data['message_id'] as String? ?? const Uuid().v4();
    final authorId = data['author_id'] as String?;

    // Пропускаем собственные сообщения (уже добавлены оптимистично)
    if (authorId != null && authorId == _currentUserId) return;

    // Проверяем, нет ли уже сообщения с таким ID
    final alreadyExists = currentState.messages.any((m) => m.id == messageId);
    if (alreadyExists) return;

    final message = Message(
      id: messageId,
      authorId: authorId,
      authorName: data['author_name'] as String?,
      role: MessageRole.player,
      content: data['content'] as String? ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, message],
    ),);
  }

  void _handleDmResponseChunk(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final chunk = data['chunk'] as String? ?? '';
    final messageId = data['message_id'] as String?;
    final currentContent = currentState.streamingContent ?? '';

    emit(currentState.copyWith(
      streamingContent: currentContent + chunk,
      streamingMessageId: messageId,
    ),);
  }

  void _handleDmResponseEnd(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final fullContent =
        data['full_content'] as String? ?? currentState.streamingContent ?? '';
    final messageId =
        data['message_id'] as String? ?? const Uuid().v4();

    final dmMessage = Message(
      id: messageId,
      role: MessageRole.dm,
      content: fullContent,
      createdAt: DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, dmMessage],
      streamingContent: null,
      streamingMessageId: null,
    ),);
  }

  void _handleDiceResult(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final diceResult = DiceResult(
      type: data['dice_type'] as String? ?? 'd20',
      baseRoll: (data['base_roll'] as num?)?.toInt(),
      modifier: (data['modifier'] as num?)?.toInt(),
      total: (data['total'] as num?)?.toInt(),
      dc: (data['dc'] as num?)?.toInt(),
      skill: data['skill'] as String?,
      success: data['success'] as bool?,
    );

    final diceMessage = Message(
      id: const Uuid().v4(),
      role: MessageRole.system,
      content: _formatDiceResult(diceResult),
      diceResult: diceResult,
      createdAt: DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, diceMessage],
    ),);
  }

  void _handleStateUpdate(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final worldStateData = data['world_state'] as Map<String, dynamic>?;
    if (worldStateData == null) return;

    final newWorldState = WorldState.fromJson(worldStateData);
    emit(currentState.copyWith(worldState: newWorldState));
  }

  void _handlePlayerJoin(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final playerName = data['player_name'] as String? ?? 'Игрок';

    final systemMessage = Message(
      id: const Uuid().v4(),
      role: MessageRole.system,
      content: '$playerName присоединился к игре',
      createdAt: DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, systemMessage],
    ),);
  }

  void _handlePlayerLeave(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final playerName = data['player_name'] as String? ?? 'Игрок';

    final systemMessage = Message(
      id: const Uuid().v4(),
      role: MessageRole.system,
      content: '$playerName покинул игру',
      createdAt: DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, systemMessage],
    ),);
  }

  void _handleError(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final errorMsg = data['message'] as String? ?? 'Неизвестная ошибка';

    final systemMessage = Message(
      id: const Uuid().v4(),
      role: MessageRole.system,
      content: 'Ошибка: $errorMsg',
      createdAt: DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, systemMessage],
    ),);
  }

  void _handleSystemMessage(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    final content = data['content'] as String? ?? '';

    final systemMessage = Message(
      id: const Uuid().v4(),
      role: MessageRole.system,
      content: content,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, systemMessage],
    ),);
  }

  void _handleVoiceChannelClosed(
    GameSessionActive currentState,
    Emitter<GameSessionState> emit,
  ) {
    // Устанавливаем флаг, чтобы UI-слой мог отреагировать и отключить голосовой канал
    emit(currentState.copyWith(voiceChannelClosed: true));
  }

  void _handleDiceRequest(
    GameSessionActive currentState,
    Map<String, dynamic> data,
    Emitter<GameSessionState> emit,
  ) {
    // Проверяем, что запрос адресован текущему игроку
    final targetPlayerId = data['target_player_id'] as String?;
    if (targetPlayerId == null || targetPlayerId != _currentUserId) {
      return;
    }

    final diceRequest = DiceRequest(
      requestId: data['request_id'] as String? ?? '',
      targetPlayerId: targetPlayerId,
      targetPlayerName: data['target_player_name'] as String? ?? '',
      diceType: data['dice_type'] as String? ?? 'd20',
      numDice: (data['num_dice'] as num?)?.toInt() ?? 1,
      modifier: (data['modifier'] as num?)?.toInt() ?? 0,
      dc: (data['dc'] as num?)?.toInt(),
      skill: data['skill'] as String?,
      reason: data['reason'] as String?,
    );

    emit(currentState.copyWith(
      pendingDiceRequest: diceRequest,
    ),);
  }

  Future<void> _onRollDice(
    RollDiceEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GameSessionActive) return;
    if (currentState.pendingDiceRequest == null) return;

    // Отправить бросок на сервер
    _repository.sendDiceRoll(
      requestId: event.requestId,
      rolls: event.rolls,
    );

    // Очистить pending request
    emit(currentState.copyWith(
      pendingDiceRequest: null,
    ),);
  }

  Future<void> _onMarkMessageRolled(
    MarkMessageRolledEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GameSessionActive) return;

    emit(currentState.copyWith(
      rolledMessageIds: {...currentState.rolledMessageIds, event.messageId},
    ),);
  }

  Future<void> _onConnectionStateChanged(
    ConnectionStateChangedEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GameSessionActive) return;

    emit(currentState.copyWith(connectionState: event.state));
  }

  Future<void> _onEndSession(
    EndSessionEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GameSessionActive) return;

    try {
      await _repository.endSession(currentState.sessionId);
      await _repository.disconnectFromSession();
      emit(GameSessionState.ended(messages: currentState.messages));
    } catch (e) {
      emit(GameSessionState.error(
        message: 'Не удалось завершить сессию: $e',
      ),);
    }
  }

  Future<void> _onLeaveSession(
    LeaveSessionEvent event,
    Emitter<GameSessionState> emit,
  ) async {
    await _cleanup();
    emit(const GameSessionState.initial());
  }

  String _formatDiceResult(DiceResult result) {
    final buffer = StringBuffer()..write('${result.type}: ');
    if (result.baseRoll != null) buffer.write('${result.baseRoll}');
    if (result.modifier != null && result.modifier != 0) {
      buffer.write(result.modifier! > 0
          ? '+${result.modifier}'
          : '${result.modifier}',);
    }
    if (result.total != null) buffer.write(' = ${result.total}');
    if (result.dc != null) buffer.write(' (DC ${result.dc})');
    if (result.success != null) {
      buffer.write(result.success! ? ' - Успех!' : ' - Провал');
    }
    if (result.skill != null) buffer.write(' [${result.skill}]');
    return buffer.toString();
  }

  Future<void> _cleanup() async {
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _repository.disconnectFromSession();
  }

  @override
  Future<void> close() async {
    await _cleanup();
    return super.close();
  }
}
