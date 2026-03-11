import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../data/scenario_repository.dart';
import 'scenario_event.dart';
import 'scenario_state.dart';

@injectable
class ScenarioBloc extends Bloc<ScenarioEvent, ScenarioState> {

  ScenarioBloc(this._repository) : super(const ScenarioInitial()) {
    on<LoadScenariosEvent>(_onLoadScenarios);
    on<CreateScenarioEvent>(_onCreateScenario);
    on<LoadScenarioEvent>(_onLoadScenario);
    on<RefineScenarioEvent>(_onRefineScenario);
    on<LoadVersionHistoryEvent>(_onLoadVersionHistory);
    on<RestoreVersionEvent>(_onRestoreVersion);
    on<PublishScenarioEvent>(_onPublishScenario);
    on<ClearErrorEvent>(_onClearError);
  }
  final ScenarioRepository _repository;

  Future<void> _onLoadScenarios(
    LoadScenariosEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioLoading());
    try {
      final scenarios = await _repository.listScenarios(status: event.status);
      emit(ScenarioLoaded(scenarios: scenarios));
    } catch (e) {
      emit(ScenarioError(message: e.toString()));
    }
  }

  Future<void> _onCreateScenario(
    CreateScenarioEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioGenerating());
    try {
      final scenario = await _repository.createScenario(event.description);
      emit(ScenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioError(
        message: 'Failed to create scenario: $e',
      ),);
    }
  }

  Future<void> _onLoadScenario(
    LoadScenarioEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioLoading());
    try {
      final scenario = await _repository.getScenario(event.id);
      emit(ScenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioError(
        message: 'Failed to load scenario: $e',
      ),);
    }
  }

  Future<void> _onRefineScenario(
    RefineScenarioEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(ScenarioGenerating(scenarioId: event.id));
    try {
      final scenario = await _repository.refineScenario(event.id, event.prompt);
      emit(ScenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioError(
        message: 'Failed to refine scenario: $e',
      ),);
    }
  }

  Future<void> _onLoadVersionHistory(
    LoadVersionHistoryEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioLoading());
    try {
      final scenario = await _repository.getScenario(event.scenarioId);
      final versions = await _repository.listVersions(event.scenarioId);
      emit(ScenarioVersionHistory(
        scenario: scenario,
        versions: versions,
      ),);
    } catch (e) {
      emit(ScenarioError(
        message: 'Failed to load version history: $e',
      ),);
    }
  }

  Future<void> _onRestoreVersion(
    RestoreVersionEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioLoading());
    try {
      final scenario = await _repository.restoreVersion(
        event.scenarioId,
        event.versionId,
      );
      emit(ScenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioError(
        message: 'Failed to restore version: $e',
      ),);
    }
  }

  Future<void> _onPublishScenario(
    PublishScenarioEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioLoading());
    try {
      final scenario = await _repository.publishScenario(event.scenarioId);
      emit(ScenarioDetail(scenario: scenario));
    } catch (e) {
      emit(ScenarioError(
        message: 'Failed to publish scenario: $e',
      ),);
    }
  }

  Future<void> _onClearError(
    ClearErrorEvent event,
    Emitter<ScenarioState> emit,
  ) async {
    emit(const ScenarioInitial());
  }
}
