import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// Module for third-party dependencies
@module
abstract class AppModule {
  @preResolve
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();

  /// Provide Dio instance from ApiClient
  @singleton
  Dio dio(ApiClient apiClient) => apiClient.dio;
}
