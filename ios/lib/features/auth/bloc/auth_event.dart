/// События аутентификации
abstract class AuthEvent {
  const AuthEvent();
}

/// Проверить сохранённую сессию
class AuthCheckSession extends AuthEvent {
  const AuthCheckSession();
}

/// Вход по email
class AuthLoginWithEmail extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginWithEmail({
    required this.email,
    required this.password,
  });
}

/// Регистрация
class AuthRegister extends AuthEvent {
  final String email;
  final String password;
  final String name;

  const AuthRegister({
    required this.email,
    required this.password,
    required this.name,
  });
}

/// Вход через Apple
class AuthSignInWithApple extends AuthEvent {
  const AuthSignInWithApple();
}

/// Выход
class AuthLogout extends AuthEvent {
  const AuthLogout();
}
