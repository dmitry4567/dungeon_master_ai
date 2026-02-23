import 'package:freezed_annotation/freezed_annotation.dart';
import 'scenario_content.dart';

part 'scenario.freezed.dart';
part 'scenario.g.dart';

/// Scenario version summary for history list
@freezed
class ScenarioVersionSummary with _$ScenarioVersionSummary {
  const factory ScenarioVersionSummary({
    required String id,
    required int version,
    required String userPrompt,
    required DateTime createdAt,
  }) = _ScenarioVersionSummary;

  factory ScenarioVersionSummary.fromJson(Map<String, dynamic> json) =>
      _$ScenarioVersionSummaryFromJson(json);
}

/// Complete scenario version with content
@freezed
class ScenarioVersion with _$ScenarioVersion {
  const factory ScenarioVersion({
    required String id,
    required int version,
    required ScenarioContent content,
    required DateTime createdAt, List<String>? validationErrors,
  }) = _ScenarioVersion;

  factory ScenarioVersion.fromJson(Map<String, dynamic> json) =>
      _$ScenarioVersionFromJson(json);
}

/// Scenario entity
@freezed
class Scenario with _$Scenario {
  const factory Scenario({
    required String id,
    required String title,
    required String status, required DateTime createdAt, // draft, published, archived
    String? currentVersionId,
    ScenarioVersion? currentVersion,
  }) = _Scenario;

  factory Scenario.fromJson(Map<String, dynamic> json) =>
      _$ScenarioFromJson(json);
}

/// Request to create a new scenario
@freezed
class CreateScenarioRequest with _$CreateScenarioRequest {
  const factory CreateScenarioRequest({
    required String description,
  }) = _CreateScenarioRequest;

  factory CreateScenarioRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateScenarioRequestFromJson(json);
}

/// Request to refine an existing scenario
@freezed
class RefineScenarioRequest with _$RefineScenarioRequest {
  const factory RefineScenarioRequest({
    required String prompt,
  }) = _RefineScenarioRequest;

  factory RefineScenarioRequest.fromJson(Map<String, dynamic> json) =>
      _$RefineScenarioRequestFromJson(json);
}
