/// События игровой сессии
abstract class GameSessionEvent {
  const GameSessionEvent();
}

/// Подключиться к сессии (WS + REST)
class ConnectToSessionEvent extends GameSessionEvent {
  final String roomId;

  const ConnectToSessionEvent({required this.roomId});
}

/// Отправить сообщение игрока
class SendMessageEvent extends GameSessionEvent {
  final String content;

  const SendMessageEvent({required this.content});
}

/// Входящее WS-сообщение
class MessageReceivedEvent extends GameSessionEvent {
  final String type;
  final Map<String, dynamic> data;

  const MessageReceivedEvent({
    required this.type,
    required this.data,
  });
}

/// Изменение состояния WS-соединения
class ConnectionStateChangedEvent extends GameSessionEvent {
  final String state;

  const ConnectionStateChangedEvent({required this.state});
}

/// Хост завершает игру
class EndSessionEvent extends GameSessionEvent {
  const EndSessionEvent();
}

/// Игрок покидает сессию
class LeaveSessionEvent extends GameSessionEvent {
  const LeaveSessionEvent();
}

/// Игрок бросает кубик в ответ на запрос
class RollDiceEvent extends GameSessionEvent {
  final String requestId;
  final List<int> rolls;

  const RollDiceEvent({
    required this.requestId,
    required this.rolls,
  });
}

/// Отметить сообщение DM как обработанное (бросок уже выполнен)
class MarkMessageRolledEvent extends GameSessionEvent {
  final String messageId;

  const MarkMessageRolledEvent({required this.messageId});
}
