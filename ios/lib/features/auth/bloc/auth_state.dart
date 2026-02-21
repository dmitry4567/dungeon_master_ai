import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/user.dart';

part 'auth_state.freezed.dart';

/// Состояние аутентификации
@freezed
class AuthState with _$AuthState {
  /// Начальное состояние
  const factory AuthState.initial() = AuthInitial;

  /// Загрузка
  const factory AuthState.loading() = AuthLoading;

  /// Пользователь авторизован
  const factory AuthState.authenticated(User user) = AuthAuthenticated;

  /// Пользователь не авторизован
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// Ошибка
  const factory AuthState.error(String message) = AuthError;
}
