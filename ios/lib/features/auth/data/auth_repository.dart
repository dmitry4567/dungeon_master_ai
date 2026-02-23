import 'package:injectable/injectable.dart';

import '../../../core/firebase/firebase_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/auth_tokens.dart';
import '../models/user.dart';
import 'apple_auth_service.dart';
import 'auth_api.dart';

/// Репозиторий аутентификации
@lazySingleton
class AuthRepository {
  AuthRepository(
    this._authApi,
    this._appleAuthService,
    this._secureStorage,
    this._firebaseService,
  );

  final AuthApi _authApi;
  final AppleAuthService _appleAuthService;
  final SecureStorage _secureStorage;
  final FirebaseService _firebaseService;

  User? _currentUser;

  /// Текущий пользователь
  User? get currentUser => _currentUser;

  /// Авторизован ли пользователь
  bool get isAuthenticated => _currentUser != null;

  /// Проверить сохранённую сессию
  Future<User?> checkSession() async {
    final hasTokens = await _secureStorage.hasTokens();
    if (!hasTokens) {
      return null;
    }

    try {
      final userData = await _authApi.getCurrentUser();
      _currentUser = User.fromJson(userData);
      await _firebaseService.setUserId(_currentUser!.id);
      return _currentUser;
    } catch (e) {
      await _secureStorage.clearTokens();
      return null;
    }
  }

  /// Вход по email
  Future<User> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final request = LoginRequest(email: email, password: password);
    final response = await _authApi.login(request);

    await _saveAuthResponse(response);
    return _currentUser!;
  }

  /// Регистрация
  Future<User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final request = RegisterRequest(
      email: email,
      password: password,
      name: name,
    );
    final response = await _authApi.register(request);

    await _saveAuthResponse(response);
    return _currentUser!;
  }

  /// Проверить доступность Sign in with Apple
  Future<bool> isAppleSignInAvailable() => _appleAuthService.isAvailable();

  /// Вход через Apple
  Future<User?> signInWithApple() async {
    final appleRequest = await _appleAuthService.signIn();
    if (appleRequest == null) {
      return null; // Пользователь отменил
    }

    final response = await _authApi.signInWithApple(appleRequest);
    await _saveAuthResponse(response);
    return _currentUser;
  }

  /// Выход
  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (e) {
      // Игнорируем ошибки при logout
    }

    await _secureStorage.clearTokens();
    await _firebaseService.clearUserId();
    _currentUser = null;
  }

  /// Сохранить ответ авторизации
  Future<void> _saveAuthResponse(AuthResponse response) async {
    await _secureStorage.saveTokens(
      accessToken: response.tokens.accessToken,
      refreshToken: response.tokens.refreshToken,
    );
    await _secureStorage.setUserId(response.user.id);

    _currentUser = response.user;
    await _firebaseService.setUserId(response.user.id);
  }
}
