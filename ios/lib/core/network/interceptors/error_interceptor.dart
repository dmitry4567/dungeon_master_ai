import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Интерсептор для обработки ошибок API
@lazySingleton
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiError = _mapDioError(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiError,
      ),
    );
  }

  ApiError _mapDioError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiError(
          code: 'timeout',
          message: 'Время ожидания истекло. Проверьте подключение к сети.',
        );

      case DioExceptionType.connectionError:
        return const ApiError(
          code: 'connection_error',
          message: 'Не удалось подключиться к серверу.',
        );

      case DioExceptionType.badResponse:
        return _parseApiError(err.response);

      case DioExceptionType.cancel:
        return const ApiError(
          code: 'cancelled',
          message: 'Запрос отменён.',
        );

      case DioExceptionType.badCertificate:
        return const ApiError(
          code: 'certificate_error',
          message: 'Ошибка сертификата безопасности.',
        );

      case DioExceptionType.unknown:
        if (err.error is SocketException) {
          return const ApiError(
            code: 'no_internet',
            message: 'Нет подключения к интернету.',
          );
        }
        return ApiError(
          code: 'unknown',
          message: err.message ?? 'Произошла неизвестная ошибка.',
        );
    }
  }

  ApiError _parseApiError(Response<dynamic>? response) {
    if (response == null) {
      return const ApiError(
        code: 'no_response',
        message: 'Сервер не ответил.',
      );
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Пробуем распарсить ошибку из body
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) {
        return ApiError(
          code: 'api_error',
          message: detail,
          statusCode: statusCode,
        );
      }
      if (detail is Map<String, dynamic>) {
        return ApiError(
          code: detail['code'] as String? ?? 'api_error',
          message: detail['message'] as String? ?? 'Ошибка сервера.',
          statusCode: statusCode,
        );
      }
    }

    // Стандартные ошибки HTTP
    return switch (statusCode) {
      400 => ApiError(
          code: 'bad_request',
          message: 'Некорректный запрос.',
          statusCode: statusCode,
        ),
      401 => ApiError(
          code: 'unauthorized',
          message: 'Требуется авторизация.',
          statusCode: statusCode,
        ),
      403 => ApiError(
          code: 'forbidden',
          message: 'Доступ запрещён.',
          statusCode: statusCode,
        ),
      404 => ApiError(
          code: 'not_found',
          message: 'Ресурс не найден.',
          statusCode: statusCode,
        ),
      422 => ApiError(
          code: 'validation_error',
          message: 'Ошибка валидации данных.',
          statusCode: statusCode,
        ),
      429 => ApiError(
          code: 'rate_limited',
          message: 'Слишком много запросов. Попробуйте позже.',
          statusCode: statusCode,
        ),
      500 || 502 || 503 || 504 => ApiError(
          code: 'server_error',
          message: 'Ошибка сервера. Попробуйте позже.',
          statusCode: statusCode,
        ),
      _ => ApiError(
          code: 'http_error',
          message: 'HTTP ошибка: $statusCode',
          statusCode: statusCode,
        ),
    };
  }
}

/// Модель ошибки API
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.statusCode,
  });

  /// Код ошибки
  final String code;

  /// Читаемое сообщение об ошибке
  final String message;

  /// HTTP статус-код (если есть)
  final int? statusCode;

  @override
  String toString() => 'ApiError(code: $code, message: $message, statusCode: $statusCode)';
}
