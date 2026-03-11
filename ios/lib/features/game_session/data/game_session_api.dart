import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/network/api_client.dart';
import '../../scenario/models/scenario_content.dart';
import '../models/message.dart';
import '../models/voice_models.dart';
import '../models/world_state.dart';

/// API для работы с игровыми сессиями
@lazySingleton
class GameSessionApi {
  GameSessionApi(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  /// Получить сессию по ID комнаты
  Future<GameSession> getSessionByRoom(String roomId) async {
    final response = await _dio.get<dynamic>('/sessions/by-room/$roomId');
    return GameSession.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Получить сообщения сессии
  Future<List<Message>> getMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get<dynamic>(
      '/sessions/$sessionId/messages',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = (response.data ?? <dynamic>[]) as List<dynamic>;
    return data
        .map((json) => Message.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  /// Получить контент сценария
  Future<ScenarioContent> getScenarioContent(String sessionId) async {
    final response = await _dio.get<dynamic>('/sessions/$sessionId/scenario');
    return ScenarioContent.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Завершить сессию (хост)
  Future<void> endSession(String sessionId) async {
    await _dio.post<dynamic>('/sessions/$sessionId/end');
  }

  /// Получить токен для голосового канала
  Future<VoiceToken> getVoiceToken(String roomId) async {
    final response = await _dio.get<dynamic>('/rooms/$roomId/voice-token');
    return VoiceToken.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
