import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/network/api_client.dart';
import '../../scenario/models/scenario_content.dart';
import '../models/message.dart';
import '../models/world_state.dart';

/// API для работы с игровыми сессиями
@lazySingleton
class GameSessionApi {
  GameSessionApi(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  /// Получить сессию по ID комнаты
  Future<GameSession> getSessionByRoom(String roomId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sessions/by-room/$roomId',
    );
    return GameSession.fromJson(response.data!);
  }

  /// Получить сообщения сессии
  Future<List<Message>> getMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/sessions/$sessionId/messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = response.data ?? [];
    return data
        .map((json) => Message.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Получить контент сценария
  Future<ScenarioContent> getScenarioContent(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sessions/$sessionId/scenario',
    );
    return ScenarioContent.fromJson(response.data!);
  }

  /// Завершить сессию (хост)
  Future<void> endSession(String sessionId) async {
    await _dio.post<Map<String, dynamic>>('/sessions/$sessionId/end');
  }
}
