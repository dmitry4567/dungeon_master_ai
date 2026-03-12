import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

/// HTTP-клиент на основе Dio
@lazySingleton
class ApiClient {
  ApiClient(this._authInterceptor, this._errorInterceptor) {
    _dio = Dio(_baseOptions);
    _dio.interceptors.addAll([
      _authInterceptor,
      _errorInterceptor,
      if (!AppConfig.current.isProduction)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => print('[DIO] $o'),
        ),
    ]);
  }

  final AuthInterceptor _authInterceptor;
  final ErrorInterceptor _errorInterceptor;

  late final Dio _dio;

  Dio get dio => _dio;

  BaseOptions get _baseOptions => BaseOptions(
    baseUrl: AppConfig.current.apiBaseUrl,
    connectTimeout: Duration.zero,
    receiveTimeout: Duration.zero,
    sendTimeout: Duration.zero,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  );

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => dio.get(path, queryParameters: queryParameters);

  Future<Response<dynamic>> post(String path, {dynamic data}) async =>
      dio.post(path, data: data);

  Future<Response<dynamic>> put(String path, {dynamic data}) async =>
      dio.put(path, data: data);

  Future<Response<dynamic>> delete(String path, {dynamic data}) async =>
      dio.delete(path, data: data);
}
