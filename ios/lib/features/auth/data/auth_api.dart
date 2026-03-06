import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../core/network/api_client.dart';
import '../models/auth_tokens.dart';

/// API для аутентификации
@lazySingleton
class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  /// Вход по email
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(response.data!);
  }

  /// Регистрация
  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(response.data!);
  }

  /// Вход через Apple
  Future<AuthResponse> signInWithApple(AppleSignInRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/apple',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(response.data!);
  }

  /// Обновление токена
  Future<AuthTokens> refreshToken(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return AuthTokens.fromJson(response.data!);
  }

  /// Выход
  Future<void> logout() async {
    await _dio.post<void>('/auth/logout');
  }

  /// Получить текущего пользователя
  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return response.data!;
  }
}
