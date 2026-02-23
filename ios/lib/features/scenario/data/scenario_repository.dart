import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scenario.dart';
import 'cached_scenario.dart';
import 'scenario_api.dart';

@singleton
class ScenarioRepository {

  ScenarioRepository(this._api, this._prefs);
  final ScenarioApi _api;
  final SharedPreferences _prefs;

  static const _cacheKey = 'cached_scenarios';

  /// List all scenarios with optional status filter
  Future<List<Scenario>> listScenarios({String? status}) async {
    try {
      final scenarios = await _api.listScenarios(status: status);

      // Cache scenarios locally
      await _cacheScenarios(scenarios);

      return scenarios;
    } catch (e) {
      // Return cached scenarios on network error
      return _getCachedScenarios();
    }
  }

  /// Create a new scenario from natural language description
  Future<Scenario> createScenario(String description) async {
    final request = CreateScenarioRequest(description: description);
    final scenario = await _api.createScenario(request);

    // Cache the newly created scenario
    await _cacheScenario(scenario);

    return scenario;
  }

  /// Get a specific scenario by ID
  Future<Scenario> getScenario(String id) async {
    try {
      final scenario = await _api.getScenario(id);
      await _cacheScenario(scenario);
      return scenario;
    } catch (e) {
      // Try to return from cache
      final cached = _getCachedScenarioById(id);
      if (cached != null) {
        return cached.toScenario();
      }
      rethrow;
    }
  }

  /// Refine an existing scenario with new instructions
  Future<Scenario> refineScenario(String id, String prompt) async {
    final request = RefineScenarioRequest(prompt: prompt);
    final scenario = await _api.refineScenario(id, request);

    // Update cache with refined scenario
    await _cacheScenario(scenario);

    return scenario;
  }

  /// List all versions of a scenario
  Future<List<ScenarioVersionSummary>> listVersions(String scenarioId) async => _api.listVersions(scenarioId);

  /// Restore a previous version of a scenario
  Future<Scenario> restoreVersion(String scenarioId, String versionId) async {
    final scenario = await _api.restoreVersion(scenarioId, versionId);
    await _cacheScenario(scenario);
    return scenario;
  }

  /// Publish a draft scenario
  Future<Scenario> publishScenario(String scenarioId) async {
    final scenario = await _api.publishScenario(scenarioId);
    await _cacheScenario(scenario);
    return scenario;
  }

  // Cache helpers
  Future<void> _cacheScenario(Scenario scenario) async {
    final cached = _getAllCachedScenarios();
    cached[scenario.id] = CachedScenario.fromScenario(scenario);
    await _saveCachedScenarios(cached);
  }

  Future<void> _cacheScenarios(List<Scenario> scenarios) async {
    final cached = _getAllCachedScenarios();
    for (final scenario in scenarios) {
      cached[scenario.id] = CachedScenario.fromScenario(scenario);
    }
    await _saveCachedScenarios(cached);
  }

  List<Scenario> _getCachedScenarios() {
    final cached = _getAllCachedScenarios();
    return cached.values.map((c) => c.toScenario()).toList();
  }

  CachedScenario? _getCachedScenarioById(String id) {
    final cached = _getAllCachedScenarios();
    return cached[id];
  }

  Map<String, CachedScenario> _getAllCachedScenarios() {
    final jsonString = _prefs.getString(_cacheKey);
    if (jsonString == null) return {};

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final result = <String, CachedScenario>{};

      for (final item in jsonList) {
        final cached = CachedScenario.fromJson(item as Map<String, dynamic>);
        result[cached.id] = cached;
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveCachedScenarios(
      Map<String, CachedScenario> scenarios,) async {
    final jsonList =
        scenarios.values.map((scenario) => scenario.toJson()).toList();
    await _prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Clear all cached scenarios
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
  }
}
