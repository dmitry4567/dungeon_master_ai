import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/room.dart';

part 'lobby_state.freezed.dart';

@freezed
class LobbyState with _$LobbyState {
  /// Начальное состояние
  const factory LobbyState.initial() = LobbyInitial;

  /// Загрузка списка комнат
  const factory LobbyState.loading() = LobbyLoading;

  /// Список комнат загружен
  const factory LobbyState.loaded({
    required List<RoomSummary> rooms,
  }) = LobbyLoaded;

  /// Создание комнаты
  const factory LobbyState.creating() = LobbyCreating;

  /// Детали комнаты (комната ожидания)
  const factory LobbyState.roomDetail({
    required Room room,
    required bool isCurrentUserHost,
  }) = LobbyRoomDetail;

  /// Игра запускается (countdown 3-2-1)
  const factory LobbyState.gameStarting({
    required Room room,
    required GameSessionResponse session,
  }) = LobbyGameStarting;

  /// Ошибка
  const factory LobbyState.error({
    required String message,
  }) = LobbyError;
}
