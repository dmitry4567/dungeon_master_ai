import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../models/scenario.dart';

@singleton
class ScenarioApi {

  ScenarioApi(this._dio);
  final Dio _dio;

  /// List all scenarios for the authenticated user
  Future<List<Scenario>> listScenarios({String? status}) async {
    final queryParams = status != null ? {'status': status} : null;

    final response = await _dio.get('/scenarios', queryParameters: queryParams);
    final data = response.data as List<dynamic>;
    return data
        .map((json) => Scenario.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new scenario from description
  Future<Scenario> createScenario(CreateScenarioRequest request) async {
    final response = await _dio.post(
      '/scenarios',
      data: request.toJson(),
    );
    return Scenario.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get a specific scenario by ID
  Future<Scenario> getScenario(String id) async {
    final response = await _dio.get('/scenarios/$id');
    return Scenario.fromJson(response.data as Map<String, dynamic>);
  }

  /// Refine an existing scenario
  Future<Scenario> refineScenario(
      String id, RefineScenarioRequest request,) async {
    final response = await _dio.post(
      '/scenarios/$id/refine',
      data: request.toJson(),
    );
    return Scenario.fromJson(response.data as Map<String, dynamic>);
  }

  /// List all versions of a scenario
  Future<List<ScenarioVersionSummary>> listVersions(String id) async {
    final response = await _dio.get('/scenarios/$id/versions');
    final data = response.data as List<dynamic>;
    return data
        .map((json) =>
            ScenarioVersionSummary.fromJson(json as Map<String, dynamic>),)
        .toList();
  }

  /// Restore a specific version
  Future<Scenario> restoreVersion(String id, String versionId) async {
    final response =
        await _dio.post('/scenarios/$id/versions/$versionId/restore');
    return Scenario.fromJson(response.data as Map<String, dynamic>);
  }

  /// Publish a draft scenario
  Future<Scenario> publishScenario(String id) async {
    final response = await _dio.post('/scenarios/$id/publish');
    return Scenario.fromJson(response.data as Map<String, dynamic>);
  }
}
