import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_session_event.freezed.dart';

@freezed
class GameSessionEvent with _$GameSessionEvent {
  /// Подключиться к сессии (WS + REST)
  const factory GameSessionEvent.connectToSession({
    required String roomId,
  }) = ConnectToSessionEvent;

  /// Отправить сообщение игрока
  const factory GameSessionEvent.sendMessage({
    required String content,
  }) = SendMessageEvent;

  /// Входящее WS-сообщение
  const factory GameSessionEvent.messageReceived({
    required String type,
    required Map<String, dynamic> data,
  }) = MessageReceivedEvent;

  /// Изменение состояния WS-соединения
  const factory GameSessionEvent.connectionStateChanged({
    required String state,
  }) = ConnectionStateChangedEvent;

  /// Хост завершает игру
  const factory GameSessionEvent.endSession() = EndSessionEvent;

  /// Игрок покидает сессию
  const factory GameSessionEvent.leaveSession() = LeaveSessionEvent;
}
