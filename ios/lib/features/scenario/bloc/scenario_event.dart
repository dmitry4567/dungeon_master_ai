/// События сценариев
abstract class ScenarioEvent {
  const ScenarioEvent();
}

/// Load list of scenarios
class LoadScenariosEvent extends ScenarioEvent {
  final String? status;

  const LoadScenariosEvent({this.status});
}

/// Create a new scenario from description
class CreateScenarioEvent extends ScenarioEvent {
  final String description;

  const CreateScenarioEvent({required this.description});
}

/// Load a specific scenario
class LoadScenarioEvent extends ScenarioEvent {
  final String id;

  const LoadScenarioEvent({required this.id});
}

/// Refine an existing scenario
class RefineScenarioEvent extends ScenarioEvent {
  final String id;
  final String prompt;

  const RefineScenarioEvent({
    required this.id,
    required this.prompt,
  });
}

/// Load version history for a scenario
class LoadVersionHistoryEvent extends ScenarioEvent {
  final String scenarioId;

  const LoadVersionHistoryEvent({required this.scenarioId});
}

/// Restore a previous version
class RestoreVersionEvent extends ScenarioEvent {
  final String scenarioId;
  final String versionId;

  const RestoreVersionEvent({
    required this.scenarioId,
    required this.versionId,
  });
}

/// Publish a draft scenario
class PublishScenarioEvent extends ScenarioEvent {
  final String scenarioId;

  const PublishScenarioEvent({required this.scenarioId});
}

/// Clear error state
class ClearErrorEvent extends ScenarioEvent {
  const ClearErrorEvent();
}
