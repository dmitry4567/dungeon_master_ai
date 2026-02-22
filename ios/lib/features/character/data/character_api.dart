import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/network/api_client.dart';
import '../models/character.dart';

/// API для работы с персонажами
@lazySingleton
class CharacterApi {
  CharacterApi(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  /// Получить список персонажей текущего пользователя
  Future<List<Character>> getCharacters() async {
    final response = await _dio.get<List<dynamic>>('/characters');
    final data = response.data ?? [];
    return data
        .map((json) => Character.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Получить персонажа по ID
  Future<Character> getCharacter(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/characters/$id');
    return Character.fromJson(response.data!);
  }

  /// Создать нового персонажа
  Future<Character> createCharacter(CreateCharacterRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/characters',
      data: request.toJson(),
    );
    return Character.fromJson(response.data!);
  }

  /// Обновить персонажа
  Future<Character> updateCharacter(
    String id,
    UpdateCharacterRequest request,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/characters/$id',
      data: request.toJson(),
    );
    return Character.fromJson(response.data!);
  }

  /// Удалить персонажа
  Future<void> deleteCharacter(String id) async {
    await _dio.delete<void>('/characters/$id');
  }
}
