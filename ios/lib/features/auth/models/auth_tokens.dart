import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth_tokens.freezed.dart';
part 'auth_tokens.g.dart';

/// Токены авторизации
@freezed
class AuthTokens with _$AuthTokens {
  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);
}

/// Ответ авторизации (токены + пользователь)
@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required AuthTokens tokens,
    required User user,
  }) = _AuthResponse;

  /// Парсинг ответа от backend API
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Backend возвращает user_id, email, name как отдельные поля
    final tokens = AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>);
    final user = User(
      id: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      createdAt: DateTime.now(),
    );
    return AuthResponse(tokens: tokens, user: user);
  }
}

/// Запрос на вход по email
@freezed
class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String email,
    required String password,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

/// Запрос на регистрацию
@freezed
class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest({
    required String email,
    required String password,
    required String name,
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
}

/// Запрос на вход через Apple
@freezed
class AppleSignInRequest with _$AppleSignInRequest {
  const factory AppleSignInRequest({
    required String identityToken,
    required String authorizationCode,
    String? name,
    String? email,
  }) = _AppleSignInRequest;

  factory AppleSignInRequest.fromJson(Map<String, dynamic> json) =>
      _$AppleSignInRequestFromJson(json);
}
