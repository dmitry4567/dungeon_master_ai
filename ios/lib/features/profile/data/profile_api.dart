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
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return response.data!;
  }

  /// Обновить имя пользователя
  Future<Map<String, dynamic>> updateName(String name) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'name': name},
    );
    return response.data!;
  }

  /// Обновить аватар пользователя
  Future<Map<String, dynamic>> updateAvatar(String avatarUrl) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'avatar_url': avatarUrl},
    );
    return response.data!;
  }

  /// Получить историю игр
  Future<List<Map<String, dynamic>>> getGameHistory() async {
    final response = await _dio.get<List<dynamic>>('/users/me/history');
    return response.data!.cast<Map<String, dynamic>>();
  }
}
