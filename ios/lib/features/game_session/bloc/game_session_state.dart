import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/dice_result.dart';
import '../models/message.dart';
import '../models/world_state.dart';

part 'game_session_state.freezed.dart';

@freezed
class GameSessionState with _$GameSessionState {
  /// Начальное состояние
  const factory GameSessionState.initial() = GameSessionInitial;

  /// Подключение к сессии
  const factory GameSessionState.connecting() = GameSessionConnecting;

  /// Активная сессия
  const factory GameSessionState.active({
    required String sessionId,
    required String roomId,
    required List<Message> messages,
    required WorldState worldState,
    required bool isHost,
    String? streamingContent,
    String? streamingMessageId,
    @Default('connected') String connectionState,
    /// Ожидающий запрос на бросок кубика (для текущего игрока)
    DiceRequest? pendingDiceRequest,
    /// ID сообщений DM, для которых уже был выполнен бросок кубика
    @Default({}) Set<String> rolledMessageIds,
  }) = GameSessionActive;

  /// Сессия завершена
  const factory GameSessionState.ended({
    required List<Message> messages,
  }) = GameSessionEnded;

  /// Ошибка
  const factory GameSessionState.error({
    required String message,
  }) = GameSessionError;
}
