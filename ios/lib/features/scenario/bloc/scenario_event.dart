import 'package:freezed_annotation/freezed_annotation.dart';

part 'scenario_event.freezed.dart';

@freezed
class ScenarioEvent with _$ScenarioEvent {
  /// Load list of scenarios
  const factory ScenarioEvent.loadScenarios({String? status}) =
      LoadScenariosEvent;

  /// Create a new scenario from description
  const factory ScenarioEvent.createScenario({required String description}) =
      CreateScenarioEvent;

  /// Load a specific scenario
  const factory ScenarioEvent.loadScenario({required String id}) =
      LoadScenarioEvent;

  /// Refine an existing scenario
  const factory ScenarioEvent.refineScenario({
    required String id,
    required String prompt,
  }) = RefineScenarioEvent;

  /// Load version history for a scenario
  const factory ScenarioEvent.loadVersionHistory({required String scenarioId}) =
      LoadVersionHistoryEvent;

  /// Restore a previous version
  const factory ScenarioEvent.restoreVersion({
    required String scenarioId,
    required String versionId,
  }) = RestoreVersionEvent;

  /// Publish a draft scenario
  const factory ScenarioEvent.publishScenario({required String scenarioId}) =
      PublishScenarioEvent;

  /// Clear error state
  const factory ScenarioEvent.clearError() = ClearErrorEvent;
}
