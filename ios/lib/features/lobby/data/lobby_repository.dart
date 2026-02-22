import 'package:injectable/injectable.dart';

import '../models/room.dart';
import 'lobby_api.dart';

/// Репозиторий для работы с игровым лобби
@lazySingleton
class LobbyRepository {
  LobbyRepository(this._api);

  final LobbyApi _api;

  // In-memory cache for room list
  List<RoomSummary>? _cachedRooms;

  /// Получить список комнат
  Future<List<RoomSummary>> listRooms({
    String? status,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedRooms != null && status == null) {
      return _cachedRooms!;
    }

    try {
      final rooms = await _api.listRooms(status: status);
      if (status == null) {
        _cachedRooms = rooms;
      }
      return rooms;
    } catch (e) {
      if (_cachedRooms != null && status == null) {
        return _cachedRooms!;
      }
      rethrow;
    }
  }

  /// Создать новую комнату
  Future<Room> createRoom({
    required String name,
    required String scenarioVersionId,
    int maxPlayers = 5,
  }) async {
    final request = CreateRoomRequest(
      name: name,
      scenarioVersionId: scenarioVersionId,
      maxPlayers: maxPlayers,
    );
    final room = await _api.createRoom(request);
    _cachedRooms = null; // Invalidate cache
    return room;
  }

  /// Получить детали комнаты
  Future<Room> getRoom(String roomId) async {
    return _api.getRoom(roomId);
  }

  /// Запрос на вступление в комнату
  Future<void> joinRoom(String roomId) async {
    await _api.joinRoom(roomId);
    _cachedRooms = null;
  }

  /// Одобрить игрока (хост)
  Future<void> approvePlayer(String roomId, String playerId) async {
    await _api.approvePlayer(roomId, playerId);
  }

  /// Отклонить игрока (хост)
  Future<void> declinePlayer(String roomId, String playerId) async {
    await _api.declinePlayer(roomId, playerId);
  }

  /// Переключить готовность
  Future<void> toggleReady({
    required String roomId,
    String? characterId,
    required bool ready,
  }) async {
    final request = ReadyRequest(
      characterId: characterId,
      ready: ready,
    );
    await _api.toggleReady(roomId, request);
  }

  /// Начать игру (хост)
  Future<GameSessionResponse> startGame(String roomId) async {
    final result = await _api.startGame(roomId);
    _cachedRooms = null;
    return result;
  }

  /// Очистить кэш
  void clearCache() {
    _cachedRooms = null;
  }
}
