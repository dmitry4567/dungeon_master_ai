import 'package:ai_dungeon_master/core/network/api_client.dart';
import 'package:injectable/injectable.dart';
import '../models/scenario.dart';

@singleton
class ScenarioApi {
  const ScenarioApi(this._apiClient);

  final ApiClient _apiClient;

  /// List all scenarios for the authenticated user
  Future<List<Scenario>> listScenarios({String? status}) async {
    final queryParams = status != null ? {'status': status} : null;

    final response = await _apiClient.get(
      '/scenarios',
      queryParameters: queryParams,
    );
    final data = (response.data as List<dynamic>?) ?? [];
    return data
        .map(
          (json) => Scenario.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  /// Create a new scenario from description
  Future<Scenario> createScenario(CreateScenarioRequest request) async {
    final response = await _apiClient.post(
      '/scenarios',
      data: request.toJson(),
    );
    return Scenario.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Get a specific scenario by ID
  Future<Scenario> getScenario(String id) async {
    final response = await _apiClient.get('/scenarios/$id');
    return Scenario.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Refine an existing scenario
  Future<Scenario> refineScenario(
    String id,
    RefineScenarioRequest request,
  ) async {
    final response = await _apiClient.post(
      '/scenarios/$id/refine',
      data: request.toJson(),
    );
    return Scenario.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// List all versions of a scenario
  Future<List<ScenarioVersionSummary>> listVersions(String id) async {
    final response = await _apiClient.get('/scenarios/$id/versions');
    final data = (response.data as List<dynamic>?) ?? [];
    return data
        .map(
          (json) => ScenarioVersionSummary.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  /// Restore a specific version
  Future<Scenario> restoreVersion(String id, String versionId) async {
    final response = await _apiClient.post(
      '/scenarios/$id/versions/$versionId/restore',
    );
    return Scenario.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Publish a draft scenario
  Future<Scenario> publishScenario(String id) async {
    final response = await _apiClient.post('/scenarios/$id/publish');
    return Scenario.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
