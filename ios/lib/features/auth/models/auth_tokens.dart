import 'user.dart';

/// Токены авторизации
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
    };
  }
}

/// Ответ авторизации (токены + пользователь)
class AuthResponse {
  final AuthTokens tokens;
  final User user;

  const AuthResponse({
    required this.tokens,
    required this.user,
  });

  /// Парсинг ответа от backend API
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Backend возвращает user_id, email, name как отдельные поля
    final tokens = AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>);
    final user = User(
      id: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      createdAt: DateTime.now(),
      avatarUrl: null,
    );
    return AuthResponse(tokens: tokens, user: user);
  }

  Map<String, dynamic> toJson() {
    return {
      'tokens': tokens.toJson(),
      'user_id': user.id,
      'email': user.email,
      'name': user.name,
    };
  }
}

/// Запрос на вход по email
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) {
    return LoginRequest(
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

/// Запрос на регистрацию
class RegisterRequest {
  final String email;
  final String password;
  final String name;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      email: json['email'] as String,
      password: json['password'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'name': name,
    };
  }
}

/// Запрос на вход через Apple
class AppleSignInRequest {
  final String identityToken;
  final String authorizationCode;
  final String? name;
  final String? email;

  const AppleSignInRequest({
    required this.identityToken,
    required this.authorizationCode,
    this.name,
    this.email,
  });

  factory AppleSignInRequest.fromJson(Map<String, dynamic> json) {
    return AppleSignInRequest(
      identityToken: json['identity_token'] as String,
      authorizationCode: json['authorization_code'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity_token': identityToken,
      'authorization_code': authorizationCode,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    };
  }
}
