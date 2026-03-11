import '../../scenario/models/scenario_content.dart';
import '../models/dice_result.dart';
import '../models/message.dart';
import '../models/world_state.dart';

/// Состояния игровой сессии
abstract class GameSessionState {
  const GameSessionState();
}

/// Начальное состояние
class GameSessionInitial extends GameSessionState {
  const GameSessionInitial();
}

/// Подключение к сессии
class GameSessionConnecting extends GameSessionState {
  const GameSessionConnecting();
}

/// Активная сессия
class GameSessionActive extends GameSessionState {
  final String sessionId;
  final String roomId;
  final List<Message> messages;
  final WorldState worldState;
  final ScenarioContent scenarioContent;
  final bool isHost;
  final String? streamingContent;
  final String? streamingMessageId;
  final String connectionState;
  final DiceRequest? pendingDiceRequest;
  final Set<String> rolledMessageIds;
  final bool voiceChannelClosed;
  final double progressPercentage;

  const GameSessionActive({
    required this.sessionId,
    required this.roomId,
    required this.messages,
    required this.worldState,
    required this.scenarioContent,
    required this.isHost,
    this.streamingContent,
    this.streamingMessageId,
    this.connectionState = 'connected',
    this.pendingDiceRequest,
    this.rolledMessageIds = const {},
    this.voiceChannelClosed = false,
    this.progressPercentage = 0.0,
  });

  GameSessionActive copyWith({
    String? sessionId,
    String? roomId,
    List<Message>? messages,
    WorldState? worldState,
    ScenarioContent? scenarioContent,
    bool? isHost,
    String? streamingContent,
    String? streamingMessageId,
    String? connectionState,
    DiceRequest? pendingDiceRequest,
    Set<String>? rolledMessageIds,
    bool? voiceChannelClosed,
    double? progressPercentage,
  }) {
    return GameSessionActive(
      sessionId: sessionId ?? this.sessionId,
      roomId: roomId ?? this.roomId,
      messages: messages ?? this.messages,
      worldState: worldState ?? this.worldState,
      scenarioContent: scenarioContent ?? this.scenarioContent,
      isHost: isHost ?? this.isHost,
      streamingContent: streamingContent ?? this.streamingContent,
      streamingMessageId: streamingMessageId ?? this.streamingMessageId,
      connectionState: connectionState ?? this.connectionState,
      pendingDiceRequest: pendingDiceRequest ?? this.pendingDiceRequest,
      rolledMessageIds: rolledMessageIds ?? this.rolledMessageIds,
      voiceChannelClosed: voiceChannelClosed ?? this.voiceChannelClosed,
      progressPercentage: progressPercentage ?? this.progressPercentage,
    );
  }
}

/// Сессия завершена
class GameSessionEnded extends GameSessionState {
  final List<Message> messages;

  const GameSessionEnded({required this.messages});
}

/// Ошибка
class GameSessionError extends GameSessionState {
  final String message;

  const GameSessionError({required this.message});
}
