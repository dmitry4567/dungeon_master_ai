import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/network/api_client.dart';
import '../models/room.dart';

/// API для работы с игровым лобби
@lazySingleton
class LobbyApi {
  LobbyApi(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  /// Получить список комнат (по умолчанию waiting + active)
  Future<List<RoomSummary>> listRooms({String? status}) async {
    final queryParams = status != null ? {'status': status} : null;
    final response =
        await _dio.get<List<dynamic>>('/rooms', queryParameters: queryParams);
    final data = response.data ?? [];
    return data
        .map((json) => RoomSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Создать новую комнату
  Future<Room> createRoom(CreateRoomRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rooms',
      data: request.toJson(),
    );
    return Room.fromJson(response.data!);
  }

  /// Получить детали комнаты
  Future<Room> getRoom(String roomId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/rooms/$roomId');
    return Room.fromJson(response.data!);
  }

  /// Запрос на вступление в комнату
  Future<void> joinRoom(String roomId) async {
    await _dio.post<Map<String, dynamic>>('/rooms/$roomId/join');
  }

  /// Одобрить игрока (хост)
  Future<void> approvePlayer(String roomId, String playerId) async {
    await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/players/$playerId/approve',
    );
  }

  /// Отклонить игрока (хост)
  Future<void> declinePlayer(String roomId, String playerId) async {
    await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/players/$playerId/decline',
    );
  }

  /// Переключить статус готовности
  Future<void> toggleReady(String roomId, ReadyRequest request) async {
    await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/ready',
      data: request.toJson(),
    );
  }

  /// Начать игру (хост)
  Future<GameSessionResponse> startGame(String roomId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/start',
    );
    return GameSessionResponse.fromJson(response.data!);
  }
}
