import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Безопасное хранилище для токенов и чувствительных данных
@lazySingleton
class SecureStorage {
  SecureStorage(this._prefs)
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  final FlutterSecureStorage _storage;
  final SharedPreferences _prefs;

  // На macOS/web в debug режиме используем SharedPreferences
  bool get _useFallback => kIsWeb || (!kIsWeb && Platform.isMacOS && kDebugMode);

  // Ключи
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';

  // Access Token
  Future<String?> getAccessToken() => _read(_accessTokenKey);

  Future<void> setAccessToken(String token) =>
      _write(_accessTokenKey, token);

  // Refresh Token
  Future<String?> getRefreshToken() => _read(_refreshTokenKey);

  Future<void> setRefreshToken(String token) =>
      _write(_refreshTokenKey, token);

  // User ID
  Future<String?> getUserId() => _read(_userIdKey);

  Future<void> setUserId(String userId) =>
      _write(_userIdKey, userId);

  /// Сохранить токены
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      setAccessToken(accessToken),
      setRefreshToken(refreshToken),
    ]);
  }

  /// Проверить наличие токенов
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  /// Очистить токены (logout)
  Future<void> clearTokens() async {
    await Future.wait([
      _delete(_accessTokenKey),
      _delete(_refreshTokenKey),
    ]);
  }

  /// Полная очистка хранилища
  Future<void> clearAll() async {
    if (_useFallback) {
      await _prefs.remove(_accessTokenKey);
      await _prefs.remove(_refreshTokenKey);
      await _prefs.remove(_userIdKey);
    } else {
      await _storage.deleteAll();
    }
  }

  // Private helpers
  Future<String?> _read(String key) async {
    if (_useFallback) {
      return _prefs.getString(key);
    }
    return _storage.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    if (_useFallback) {
      await _prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<void> _delete(String key) async {
    if (_useFallback) {
      await _prefs.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }
}
