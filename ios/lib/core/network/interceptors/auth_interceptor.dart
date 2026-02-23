import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../storage/secure_storage.dart';

/// Интерсептор для добавления JWT токена к запросам
@lazySingleton
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage);

  final SecureStorage _secureStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Пропускаем auth-эндпоинты
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    final accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // При 401 пробуем обновить токен
    if (err.response?.statusCode == 401 && !_isAuthEndpoint(err.requestOptions.path)) {
      final refreshed = await _refreshToken(err.requestOptions);
      if (refreshed != null) {
        return handler.resolve(refreshed);
      }
    }

    handler.next(err);
  }

  /// Попытка обновить токен и повторить запрос
  Future<Response<dynamic>?> _refreshToken(RequestOptions options) async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) {
      await _secureStorage.clearTokens();
      return null;
    }

    try {
      final dio = Dio();
      final response = await dio.post<Map<String, dynamic>>(
        '${options.baseUrl}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;
      if (data != null) {
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null) {
          await _secureStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken,
          );

          // Повторяем оригинальный запрос
          options.headers['Authorization'] = 'Bearer $newAccessToken';
          return dio.fetch(options);
        }
      }
    } on DioException {
      await _secureStorage.clearTokens();
    }

    return null;
  }

  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh');
}
