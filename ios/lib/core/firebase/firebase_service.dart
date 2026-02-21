import 'dart:async';
import 'dart:isolate';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../config/app_config.dart';

/// Сервис Firebase (Crashlytics + Analytics)
@lazySingleton
class FirebaseService {
  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;

  /// Получить Firebase Analytics
  FirebaseAnalytics? get analytics => _analytics;

  /// Инициализировать Firebase
  Future<void> init() async {
    await Firebase.initializeApp();

    final config = AppConfig.current;

    // Crashlytics
    if (config.enableCrashlytics) {
      _crashlytics = FirebaseCrashlytics.instance;
      await _crashlytics!.setCrashlyticsCollectionEnabled(true);

      // Ловим ошибки Flutter
      FlutterError.onError = _crashlytics!.recordFlutterFatalError;

      // Ловим ошибки в изолятах
      Isolate.current.addErrorListener(RawReceivePort((dynamic pair) async {
        final errorAndStacktrace = pair as List<dynamic>;
        await _crashlytics!.recordError(
          errorAndStacktrace.first,
          errorAndStacktrace.last as StackTrace?,
          fatal: true,
        );
      },).sendPort);

      // Ловим ошибки платформы
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics!.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Analytics
    if (config.enableAnalytics) {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
    }
  }

  /// Залогировать ошибку в Crashlytics
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (_crashlytics == null) return;

    await _crashlytics!.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  /// Установить идентификатор пользователя
  Future<void> setUserId(String userId) async {
    await _crashlytics?.setUserIdentifier(userId);
    await _analytics?.setUserId(id: userId);
  }

  /// Очистить идентификатор пользователя (logout)
  Future<void> clearUserId() async {
    await _crashlytics?.setUserIdentifier('');
    await _analytics?.setUserId(id: null);
  }

  /// Залогировать событие в Analytics
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics?.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  /// Залогировать начало игровой сессии
  Future<void> logGameSessionStart({
    required String roomId,
    required String scenarioId,
    required int playerCount,
  }) async {
    await logEvent(
      name: 'game_session_start',
      parameters: {
        'room_id': roomId,
        'scenario_id': scenarioId,
        'player_count': playerCount,
      },
    );
  }

  /// Залогировать окончание игровой сессии
  Future<void> logGameSessionEnd({
    required String roomId,
    required int durationMinutes,
    required int messageCount,
  }) async {
    await logEvent(
      name: 'game_session_end',
      parameters: {
        'room_id': roomId,
        'duration_minutes': durationMinutes,
        'message_count': messageCount,
      },
    );
  }

  /// Залогировать создание персонажа
  Future<void> logCharacterCreated({
    required String characterClass,
    required String race,
    required int level,
  }) async {
    await logEvent(
      name: 'character_created',
      parameters: {
        'character_class': characterClass,
        'race': race,
        'level': level,
      },
    );
  }

  /// Залогировать создание сценария
  Future<void> logScenarioCreated({
    required String scenarioId,
    required int actCount,
  }) async {
    await logEvent(
      name: 'scenario_created',
      parameters: {
        'scenario_id': scenarioId,
        'act_count': actCount,
      },
    );
  }
}
