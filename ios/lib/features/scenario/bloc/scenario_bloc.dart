import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../data/scenario_repository.dart';
import 'scenario_event.dart';
import 'scenario_state.dart';

@injectable
class ScenarioBloc extends Bloc<ScenarioEvent, ScenarioState> {
  final ScenarioRepository _repository;

  ScenarioBloc(this._repository) : super(const ScenarioState.initial()) {
    on<LoadScenariosEvent>(_onLoadScenarios);
    on<CreateScenarioEvent>(_onCreateScenario);
    on<LoadScenarioEvent>(_onLoadScenario);
    on<RefineScenarioEvent>(_onRefineScenario);
    on<LoadVersionHistoryEvent>(_onLoadVersionHistory);
    on<RestoreVersionEvent>(_onRestoreVersion);
    on<ClearErrorEvent>(_onClearError);
  }

  Future<void> _onLoadScenarios(
    LoadScenariosEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioState.loading());
    try {
      final scenarios = await _repository.listScenarios(status: event.status);
      emit(ScenarioState.loaded(scenarios: scenarios));
    } catch (e) {
      emit(ScenarioState.error(message: e.toString()));
    }
  }

  Future<void> _onCreateScenario(
    CreateScenarioEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioState.generating());
    try {
      final scenario = await _repository.createScenario(event.description);
      emit(ScenarioState.scenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioState.error(
        message: 'Failed to create scenario: ${e.toString()}',
      ));
    }
  }

  Future<void> _onLoadScenario(
    LoadScenarioEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioState.loading());
    try {
      final scenario = await _repository.getScenario(event.id);
      emit(ScenarioState.scenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioState.error(
        message: 'Failed to load scenario: ${e.toString()}',
      ));
    }
  }

  Future<void> _onRefineScenario(
    RefineScenarioEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(ScenarioState.generating(scenarioId: event.id));
    try {
      final scenario = await _repository.refineScenario(event.id, event.prompt);
      emit(ScenarioState.scenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioState.error(
        message: 'Failed to refine scenario: ${e.toString()}',
      ));
    }
  }

  Future<void> _onLoadVersionHistory(
    LoadVersionHistoryEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioState.loading());
    try {
      final scenario = await _repository.getScenario(event.scenarioId);
      final versions = await _repository.listVersions(event.scenarioId);
      emit(ScenarioState.versionHistory(
        scenario: scenario,
        versions: versions,
      ));
    } catch (e) {
      emit(ScenarioState.error(
        message: 'Failed to load version history: ${e.toString()}',
      ));
    }
  }

  Future<void> _onRestoreVersion(
    RestoreVersionEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioState.loading());
    try {
      final scenario = await _repository.restoreVersion(
        event.scenarioId,
        event.versionId,
      );
      emit(ScenarioState.scenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioState.error(
        message: 'Failed to restore version: ${e.toString()}',
      ));
    }
  }

  Future<void> _onClearError(
    ClearErrorEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioState.initial());
  }
}
