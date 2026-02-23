import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_event.freezed.dart';

/// События аутентификации
@freezed
class AuthEvent with _$AuthEvent {
  /// Проверить сохранённую сессию
  const factory AuthEvent.checkSession() = AuthCheckSession;

  /// Вход по email
  const factory AuthEvent.loginWithEmail({
    required String email,
    required String password,
  }) = AuthLoginWithEmail;

  /// Регистрация
  const factory AuthEvent.register({
    required String email,
    required String password,
    required String name,
  }) = AuthRegister;

  /// Вход через Apple
  const factory AuthEvent.signInWithApple() = AuthSignInWithApple;

  /// Выход
  const factory AuthEvent.logout() = AuthLogout;
}
