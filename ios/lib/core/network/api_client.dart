import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// HTTP-клиент на основе Dio
@lazySingleton
class ApiClient {
  ApiClient(
    this._authInterceptor,
    this._errorInterceptor,
  ) {
    _dio = Dio(_baseOptions);
    _dio.interceptors.addAll([
      _authInterceptor,
      _errorInterceptor,
      if (!AppConfig.current.isProduction) LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => print('[DIO] $o'), // ignore: avoid_print
      ),
    ]);
  }

  final AuthInterceptor _authInterceptor;
  final ErrorInterceptor _errorInterceptor;
  late final Dio _dio;

  /// Получить экземпляр Dio для Retrofit
  Dio get dio => _dio;

  /// Базовые настройки
  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConfig.current.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
}
