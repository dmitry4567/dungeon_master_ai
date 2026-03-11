import 'dart:convert';

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
    final response = await _dio.get<dynamic>('/characters');
    final data = (response.data ?? <dynamic>[]) as List<dynamic>;
    return data
        .map((json) => Character.fromJson(
            jsonDecode(jsonEncode(json)) as Map<String, dynamic>))
        .toList();
  }

  /// Получить персонажа по ID
  Future<Character> getCharacter(String id) async {
    final response = await _dio.get<dynamic>('/characters/$id');
    return Character.fromJson(
        jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>);
  }

  /// Создать нового персонажа
  Future<Character> createCharacter(CreateCharacterRequest request) async {
    final response = await _dio.post<dynamic>(
      '/characters',
      data: request.toJson(),
    );
    return Character.fromJson(
        jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>);
  }

  /// Обновить персонажа
  Future<Character> updateCharacter(
    String id,
    UpdateCharacterRequest request,
  ) async {
    final response = await _dio.patch<dynamic>(
      '/characters/$id',
      data: request.toJson(),
    );
    return Character.fromJson(
        jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>);
  }

  /// Удалить персонажа
  Future<void> deleteCharacter(String id) async {
    await _dio.delete<dynamic>('/characters/$id');
  }
}
