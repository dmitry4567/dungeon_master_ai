import '../models/user.dart';

/// Состояние аутентификации
abstract class AuthState {
  const AuthState();
}

/// Начальное состояние
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Загрузка
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Пользователь авторизован
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);
}

/// Пользователь не авторизован
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Ошибка
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);
}
