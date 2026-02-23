import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/scenario.dart';

part 'scenario_state.freezed.dart';

@freezed
class ScenarioState with _$ScenarioState {
  /// Initial state
  const factory ScenarioState.initial() = ScenarioInitial;

  /// Loading scenarios list
  const factory ScenarioState.loading() = ScenarioLoading;

  /// Scenarios list loaded successfully
  const factory ScenarioState.loaded({
    required List<Scenario> scenarios,
  }) = ScenarioLoaded;

  /// Creating or refining a scenario (AI generation)
  const factory ScenarioState.generating({
    String? scenarioId, // null for new, set for refinement
  }) = ScenarioGenerating;

  /// Single scenario loaded with details
  const factory ScenarioState.scenarioDetail({
    required Scenario scenario,
  }) = ScenarioDetail;

  /// Version history loaded
  const factory ScenarioState.versionHistory({
    required Scenario scenario,
    required List<ScenarioVersionSummary> versions,
  }) = ScenarioVersionHistory;

  /// Error state
  const factory ScenarioState.error({
    required String message,
  }) = ScenarioError;
}
