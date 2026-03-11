import '../models/scenario.dart';

/// Состояния сценариев
abstract class ScenarioState {
  const ScenarioState();
}

/// Initial state
class ScenarioInitial extends ScenarioState {
  const ScenarioInitial();
}

/// Loading scenarios list
class ScenarioLoading extends ScenarioState {
  const ScenarioLoading();
}

/// Scenarios list loaded successfully
class ScenarioLoaded extends ScenarioState {
  final List<Scenario> scenarios;

  const ScenarioLoaded({required this.scenarios});
}

/// Creating or refining a scenario (AI generation)
class ScenarioGenerating extends ScenarioState {
  final String? scenarioId;

  const ScenarioGenerating({this.scenarioId});
}

/// Single scenario loaded with details
class ScenarioDetail extends ScenarioState {
  final Scenario scenario;

  const ScenarioDetail({required this.scenario});
}

/// Version history loaded
class ScenarioVersionHistory extends ScenarioState {
  final Scenario scenario;
  final List<ScenarioVersionSummary> versions;

  const ScenarioVersionHistory({
    required this.scenario,
    required this.versions,
  });
}

/// Error state
class ScenarioError extends ScenarioState {
  final String message;

  const ScenarioError({required this.message});
}
