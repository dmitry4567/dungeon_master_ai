/// События лобби
abstract class LobbyEvent {
  const LobbyEvent();
}

/// Загрузить список комнат
class LoadRoomsEvent extends LobbyEvent {
  final String? status;

  const LoadRoomsEvent({this.status});
}

/// Создать новую комнату
class CreateRoomEvent extends LobbyEvent {
  final String name;
  final String scenarioVersionId;
  final int maxPlayers;
  final String? characterId;

  const CreateRoomEvent({
    required this.name,
    required this.scenarioVersionId,
    this.maxPlayers = 5,
    this.characterId,
  });
}

/// Загрузить детали комнаты
class LoadRoomEvent extends LobbyEvent {
  final String roomId;

  const LoadRoomEvent({required this.roomId});
}

/// Обновить детали комнаты (повторный запрос)
class RefreshRoomEvent extends LobbyEvent {
  final String roomId;

  const RefreshRoomEvent({required this.roomId});
}

/// Запрос на вступление в комнату
class JoinRoomEvent extends LobbyEvent {
  final String roomId;

  const JoinRoomEvent({required this.roomId});
}

/// Одобрить игрока
class ApprovePlayerEvent extends LobbyEvent {
  final String roomId;
  final String playerId;

  const ApprovePlayerEvent({
    required this.roomId,
    required this.playerId,
  });
}

/// Отклонить игрока
class DeclinePlayerEvent extends LobbyEvent {
  final String roomId;
  final String playerId;

  const DeclinePlayerEvent({
    required this.roomId,
    required this.playerId,
  });
}

/// Переключить готовность
class ToggleReadyEvent extends LobbyEvent {
  final String roomId;
  final bool ready;
  final String? characterId;

  const ToggleReadyEvent({
    required this.roomId,
    required this.ready,
    this.characterId,
  });
}

/// Начать игру
class StartGameEvent extends LobbyEvent {
  final String roomId;

  const StartGameEvent({required this.roomId});
}

/// Очистить ошибку
class ClearLobbyErrorEvent extends LobbyEvent {
  const ClearLobbyErrorEvent();
}
