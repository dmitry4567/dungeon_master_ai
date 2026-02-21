import 'package:flutter/foundation.dart';

/// Конфигурация приложения, загружаемая из переменных окружения
class AppConfig {
  const AppConfig._({
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.environment,
    required this.enableCrashlytics,
    required this.enableAnalytics,
  });

  /// API URL бэкенда
  final String apiBaseUrl;

  /// WebSocket URL бэкенда
  final String wsBaseUrl;

  /// Текущее окружение
  final Environment environment;

  /// Включить Firebase Crashlytics
  final bool enableCrashlytics;

  /// Включить Firebase Analytics
  final bool enableAnalytics;

  /// Режим разработки
  bool get isDevelopment => environment == Environment.development;

  /// Режим продакшена
  bool get isProduction => environment == Environment.production;

  /// Режим стейджинга
  bool get isStaging => environment == Environment.staging;

  /// Конфигурация для разработки
  static const development = AppConfig._(
    apiBaseUrl: 'http://192.168.0.139:8000/api/v1',
    wsBaseUrl: 'ws://192.168.0.139:8000/api/v1/ws',
    environment: Environment.development,
    enableCrashlytics: false,
    enableAnalytics: false,
  );

  /// Конфигурация для стейджинга
  static const staging = AppConfig._(
    apiBaseUrl: 'https://staging-api.aidungeonmaster.com/v1',
    wsBaseUrl: 'wss://staging-api.aidungeonmaster.com/v1/ws',
    environment: Environment.staging,
    enableCrashlytics: true,
    enableAnalytics: true,
  );

  /// Конфигурация для продакшена
  static const production = AppConfig._(
    apiBaseUrl: 'https://api.aidungeonmaster.com/v1',
    wsBaseUrl: 'wss://api.aidungeonmaster.com/v1/ws',
    environment: Environment.production,
    enableCrashlytics: true,
    enableAnalytics: true,
  );

  /// Текущая конфигурация приложения
  static AppConfig get current {
    if (kReleaseMode) {
      return production;
    }

    const envName = String.fromEnvironment('ENV', defaultValue: 'development');

    return switch (envName) {
      'production' => production,
      'staging' => staging,
      _ => development,
    };
  }
}

/// Окружение приложения
enum Environment {
  development,
  staging,
  production,
}
