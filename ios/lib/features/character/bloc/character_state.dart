import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/dnd_data.dart';

part 'character_state.freezed.dart';

/// Состояние CharacterBloc
@freezed
sealed class CharacterState with _$CharacterState {
  /// Начальное состояние
  const factory CharacterState.initial() = CharacterInitial;

  /// Загрузка списка персонажей
  const factory CharacterState.loading() = CharacterLoading;

  /// Список персонажей загружен
  const factory CharacterState.loaded({
    required List<Character> characters,
  }) = CharacterLoaded;

  /// Просмотр конкретного персонажа
  const factory CharacterState.detail({
    required Character character,
  }) = CharacterDetail;

  /// Создание персонажа (мастер)
  const factory CharacterState.creating({
    required CharacterCreationForm form,
  }) = CharacterCreating;

  /// Отправка формы
  const factory CharacterState.submitting({
    required CharacterCreationForm form,
  }) = CharacterSubmitting;

  /// Персонаж успешно создан
  const factory CharacterState.created({
    required Character character,
  }) = CharacterCreated;

  /// Персонаж успешно удалён
  const factory CharacterState.deleted({
    required String characterId,
  }) = CharacterDeleted;

  /// Ошибка
  const factory CharacterState.error({
    required String message,
    CharacterState? previousState,
  }) = CharacterError;
}

/// Форма создания персонажа
@freezed
class CharacterCreationForm with _$CharacterCreationForm {
  const CharacterCreationForm._();

  const factory CharacterCreationForm({
    @Default(0) int currentStep,
    DndClass? selectedClass,
    DndRace? selectedRace,
    @Default(AbilityScores()) AbilityScores abilityScores,
    @Default('') String name,
    @Default('') String backstory,
    @Default([]) List<String> validationErrors,
  }) = _CharacterCreationForm;

  /// Шаги мастера
  static const int totalSteps = 4;
  static const int classStep = 0;
  static const int raceStep = 1;
  static const int abilitiesStep = 2;
  static const int backstoryStep = 3;

  /// Можно ли перейти к следующему шагу
  bool get canProceed {
    return switch (currentStep) {
      classStep => selectedClass != null,
      raceStep => selectedRace != null,
      abilitiesStep => _isAbilityScoresValid,
      backstoryStep => name.isNotEmpty,
      _ => false,
    };
  }

  bool get _isAbilityScoresValid {
    final total = abilityScores.total;
    return total >= 60 && total <= 90;
  }

  /// Последний ли это шаг
  bool get isLastStep => currentStep == totalSteps - 1;

  /// Первый ли это шаг
  bool get isFirstStep => currentStep == 0;

  /// Процент заполнения (для индикатора прогресса)
  double get progress => (currentStep + 1) / totalSteps;

  /// Название текущего шага
  String get currentStepTitle {
    return switch (currentStep) {
      classStep => 'Выберите класс',
      raceStep => 'Выберите расу',
      abilitiesStep => 'Распределите характеристики',
      backstoryStep => 'Имя и предыстория',
      _ => '',
    };
  }

  /// Характеристики с бонусами расы
  AbilityScores get abilityScoresWithRacialBonus {
    if (selectedRace == null) return abilityScores;

    var scores = abilityScores;
    for (final entry in selectedRace!.abilityBonuses.entries) {
      final current = scores.getValue(entry.key);
      scores = scores.withAbility(entry.key, current + entry.value);
    }
    return scores;
  }

  /// Конвертировать в запрос на создание
  CreateCharacterRequest toRequest() {
    return CreateCharacterRequest(
      name: name.trim(),
      characterClass: selectedClass!.id,
      race: selectedRace!.id,
      abilityScores: abilityScoresWithRacialBonus,
      backstory: backstory.trim().isEmpty ? null : backstory.trim(),
    );
  }
}
