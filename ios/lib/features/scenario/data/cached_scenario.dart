import 'dart:convert';
import '../models/scenario.dart';
import '../models/scenario_content.dart';

/// Simple in-memory cache for scenarios (for Phase 5 MVP)
/// TODO: Replace with persistent cache (Isar or SQLite) in future phases
class CachedScenario {

  CachedScenario({
    required this.id,
    required this.title,
    required this.status,
    required this.cachedAt, this.contentJson,
  });

  /// Create CachedScenario from Scenario model
  factory CachedScenario.fromScenario(Scenario scenario) {
    String? contentJson;
    if (scenario.currentVersion != null) {
      contentJson = jsonEncode(scenario.currentVersion!.content.toJson());
    }

    return CachedScenario(
      id: scenario.id,
      title: scenario.title,
      status: scenario.status,
      contentJson: contentJson,
      cachedAt: DateTime.now(),
    );
  }

  /// Create from JSON (SharedPreferences)
  factory CachedScenario.fromJson(Map<String, dynamic> json) => CachedScenario(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      contentJson: json['contentJson'] as String?,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  final String id;
  final String title;
  final String status;
  final String? contentJson; // Serialized ScenarioContent (current version)
  final DateTime cachedAt;

  /// Convert CachedScenario to Scenario model
  Scenario toScenario() {
    ScenarioVersion? currentVersion;
    if (contentJson != null) {
      final content = ScenarioContent.fromJson(jsonDecode(contentJson!) as Map<String, dynamic>);
      currentVersion = ScenarioVersion(
        id: id, // Use scenario ID as placeholder
        version: 1,
        content: content,
        createdAt: cachedAt,
      );
    }

    return Scenario(
      id: id,
      title: title,
      status: status,
      currentVersion: currentVersion,
      createdAt: cachedAt,
    );
  }

  /// Convert to JSON for SharedPreferences storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        'contentJson': contentJson,
        'cachedAt': cachedAt.toIso8601String(),
      };
}
