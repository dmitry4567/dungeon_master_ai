import '../models/room.dart';

/// Состояния лобби
abstract class LobbyState {
  const LobbyState();
}

/// Начальное состояние
class LobbyInitial extends LobbyState {
  const LobbyInitial();
}

/// Загрузка списка комнат
class LobbyLoading extends LobbyState {
  const LobbyLoading();
}

/// Список комнат загружен
class LobbyLoaded extends LobbyState {
  final List<RoomSummary> rooms;

  const LobbyLoaded({required this.rooms});
}

/// Создание комнаты
class LobbyCreating extends LobbyState {
  const LobbyCreating();
}

/// Детали комнаты (комната ожидания)
class LobbyRoomDetail extends LobbyState {
  final Room room;
  final bool isCurrentUserHost;

  const LobbyRoomDetail({
    required this.room,
    required this.isCurrentUserHost,
  });
}

/// Игра запускается (countdown 3-2-1)
class LobbyGameStarting extends LobbyState {
  final Room room;
  final GameSessionResponse session;

  const LobbyGameStarting({
    required this.room,
    required this.session,
  });
}

/// Ошибка
class LobbyError extends LobbyState {
  final String message;

  const LobbyError({required this.message});
}
