import 'package:freezed_annotation/freezed_annotation.dart';

part 'lobby_event.freezed.dart';

@freezed
class LobbyEvent with _$LobbyEvent {
  /// Загрузить список комнат
  const factory LobbyEvent.loadRooms({String? status}) = LoadRoomsEvent;

  /// Создать новую комнату
  const factory LobbyEvent.createRoom({
    required String name,
    required String scenarioVersionId,
    @Default(5) int maxPlayers,
    String? characterId,
  }) = CreateRoomEvent;

  /// Загрузить детали комнаты
  const factory LobbyEvent.loadRoom({required String roomId}) = LoadRoomEvent;

  /// Обновить детали комнаты (повторный запрос)
  const factory LobbyEvent.refreshRoom({required String roomId}) =
      RefreshRoomEvent;

  /// Запрос на вступление в комнату
  const factory LobbyEvent.joinRoom({required String roomId}) = JoinRoomEvent;

  /// Одобрить игрока
  const factory LobbyEvent.approvePlayer({
    required String roomId,
    required String playerId,
  }) = ApprovePlayerEvent;

  /// Отклонить игрока
  const factory LobbyEvent.declinePlayer({
    required String roomId,
    required String playerId,
  }) = DeclinePlayerEvent;

  /// Переключить готовность
  const factory LobbyEvent.toggleReady({
    required String roomId,
    required bool ready, String? characterId,
  }) = ToggleReadyEvent;

  /// Начать игру
  const factory LobbyEvent.startGame({required String roomId}) =
      StartGameEvent;

  /// Очистить ошибку
  const factory LobbyEvent.clearError() = ClearLobbyErrorEvent;
}
