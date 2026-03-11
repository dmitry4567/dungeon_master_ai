import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/network/api_client.dart';

/// API для профиля пользователя
@lazySingleton
class ProfileApi {
  ProfileApi(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  /// Получить профиль текущего пользователя
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get<dynamic>('/users/me');
    return jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
  }

  /// Обновить имя пользователя
  Future<Map<String, dynamic>> updateName(String name) async {
    final response = await _dio.patch<dynamic>(
      '/users/me',
      data: {'name': name},
    );
    return jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
  }

  /// Обновить аватар пользователя
  Future<Map<String, dynamic>> updateAvatar(String avatarUrl) async {
    final response = await _dio.patch<dynamic>(
      '/users/me',
      data: {'avatar_url': avatarUrl},
    );
    return jsonDecode(jsonEncode(response.data)) as Map<String, dynamic>;
  }

  /// Получить историю игр
  Future<List<Map<String, dynamic>>> getGameHistory() async {
    final response = await _dio.get<dynamic>('/users/me/history');
    final list = jsonDecode(jsonEncode(response.data ?? <dynamic>[])) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}
