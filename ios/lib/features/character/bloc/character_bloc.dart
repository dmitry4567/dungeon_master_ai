import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/character_repository.dart';
import 'character_event.dart';
import 'character_state.dart';

/// Bloc для управления персонажами
@injectable
class CharacterBloc extends Bloc<CharacterEvent, CharacterState> {
  CharacterBloc(this._repository) : super(const CharacterState.initial()) {
    on<LoadCharactersEvent>(_onLoadCharacters);
    on<LoadCharacterEvent>(_onLoadCharacter);
    on<StartCreationEvent>(_onStartCreation);
    on<SelectClassEvent>(_onSelectClass);
    on<SelectRaceEvent>(_onSelectRace);
    on<UpdateAbilityScoresEvent>(_onUpdateAbilityScores);
    on<UpdateNameEvent>(_onUpdateName);
    on<UpdateBackstoryEvent>(_onUpdateBackstory);
    on<SubmitCreationEvent>(_onSubmitCreation);
    on<DeleteCharacterEvent>(_onDeleteCharacter);
    on<UpdateCharacterEvent>(_onUpdateCharacter);
    on<NextStepEvent>(_onNextStep);
    on<PreviousStepEvent>(_onPreviousStep);
    on<ClearErrorEvent>(_onClearError);
  }

  final CharacterRepository _repository;

  Future<void> _onLoadCharacters(
    LoadCharactersEvent event,
    Emitter<CharacterState> emit,
  ) async {
    emit(const CharacterState.loading());

    try {
      final characters = await _repository.getCharacters(
        forceRefresh: event.forceRefresh,
      );
      emit(CharacterState.loaded(characters: characters));
    } catch (e) {
      emit(CharacterState.error(
        message: 'Не удалось загрузить персонажей: ${e.toString()}',
        previousState: state,
      ));
    }
  }

  Future<void> _onLoadCharacter(
    LoadCharacterEvent event,
    Emitter<CharacterState> emit,
  ) async {
    emit(const CharacterState.loading());

    try {
      final character = await _repository.getCharacter(
        event.id,
        forceRefresh: event.forceRefresh,
      );
      emit(CharacterState.detail(character: character));
    } catch (e) {
      emit(CharacterState.error(
        message: 'Не удалось загрузить персонажа: ${e.toString()}',
        previousState: state,
      ));
    }
  }

  void _onStartCreation(
    StartCreationEvent event,
    Emitter<CharacterState> emit,
  ) {
    emit(const CharacterState.creating(
      form: CharacterCreationForm(),
    ));
  }

  void _onSelectClass(
    SelectClassEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterCreating) {
      emit(CharacterState.creating(
        form: currentState.form.copyWith(
          selectedClass: event.selectedClass,
        ),
      ));
    }
  }

  void _onSelectRace(
    SelectRaceEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterCreating) {
      emit(CharacterState.creating(
        form: currentState.form.copyWith(
          selectedRace: event.selectedRace,
        ),
      ));
    }
  }

  void _onUpdateAbilityScores(
    UpdateAbilityScoresEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterCreating) {
      emit(CharacterState.creating(
        form: currentState.form.copyWith(
          abilityScores: event.abilityScores,
        ),
      ));
    }
  }

  void _onUpdateName(
    UpdateNameEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterCreating) {
      emit(CharacterState.creating(
        form: currentState.form.copyWith(
          name: event.name,
        ),
      ));
    }
  }

  void _onUpdateBackstory(
    UpdateBackstoryEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterCreating) {
      emit(CharacterState.creating(
        form: currentState.form.copyWith(
          backstory: event.backstory,
        ),
      ));
    }
  }

  Future<void> _onSubmitCreation(
    SubmitCreationEvent event,
    Emitter<CharacterState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CharacterCreating) return;

    final form = currentState.form;

    // Проверка заполнения формы
    if (form.selectedClass == null ||
        form.selectedRace == null ||
        form.name.trim().isEmpty) {
      emit(CharacterState.creating(
        form: form.copyWith(
          validationErrors: ['Заполните все обязательные поля'],
        ),
      ));
      return;
    }

    emit(CharacterState.submitting(form: form));

    try {
      final request = form.toRequest();

      // Валидация через репозиторий
      final validationErrors = _repository.validateCharacter(request);
      if (validationErrors.isNotEmpty) {
        emit(CharacterState.creating(
          form: form.copyWith(validationErrors: validationErrors),
        ));
        return;
      }

      final character = await _repository.createCharacter(request);
      emit(CharacterState.created(character: character));
    } on CharacterValidationException catch (e) {
      emit(CharacterState.creating(
        form: form.copyWith(validationErrors: e.errors),
      ));
    } catch (e) {
      emit(CharacterState.error(
        message: 'Не удалось создать персонажа: ${e.toString()}',
        previousState: CharacterState.creating(form: form),
      ));
    }
  }

  Future<void> _onDeleteCharacter(
    DeleteCharacterEvent event,
    Emitter<CharacterState> emit,
  ) async {
    final previousState = state;
    emit(const CharacterState.loading());

    try {
      await _repository.deleteCharacter(event.id);
      emit(CharacterState.deleted(characterId: event.id));
    } catch (e) {
      emit(CharacterState.error(
        message: 'Не удалось удалить персонажа: ${e.toString()}',
        previousState: previousState,
      ));
    }
  }

  Future<void> _onUpdateCharacter(
    UpdateCharacterEvent event,
    Emitter<CharacterState> emit,
  ) async {
    final previousState = state;
    emit(const CharacterState.loading());

    try {
      final character = await _repository.updateCharacter(
        event.id,
        event.request,
      );
      emit(CharacterState.detail(character: character));
    } catch (e) {
      emit(CharacterState.error(
        message: 'Не удалось обновить персонажа: ${e.toString()}',
        previousState: previousState,
      ));
    }
  }

  void _onNextStep(
    NextStepEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterCreating) {
      final form = currentState.form;
      if (form.canProceed && !form.isLastStep) {
        emit(CharacterState.creating(
          form: form.copyWith(
            currentStep: form.currentStep + 1,
            validationErrors: [],
          ),
        ));
      }
    }
  }

  void _onPreviousStep(
    PreviousStepEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterCreating) {
      final form = currentState.form;
      if (!form.isFirstStep) {
        emit(CharacterState.creating(
          form: form.copyWith(
            currentStep: form.currentStep - 1,
            validationErrors: [],
          ),
        ));
      }
    }
  }

  void _onClearError(
    ClearErrorEvent event,
    Emitter<CharacterState> emit,
  ) {
    final currentState = state;
    if (currentState is CharacterError && currentState.previousState != null) {
      emit(currentState.previousState!);
    } else {
      emit(const CharacterState.initial());
    }
  }
}
