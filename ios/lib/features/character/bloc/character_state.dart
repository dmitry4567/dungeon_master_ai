import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/dnd_data.dart';

/// Состояние CharacterBloc
abstract class CharacterState {
  const CharacterState();
}

/// Начальное состояние
class CharacterInitial extends CharacterState {
  const CharacterInitial();
}

/// Загрузка списка персонажей
class CharacterLoading extends CharacterState {
  const CharacterLoading();
}

/// Список персонажей загружен
class CharacterLoaded extends CharacterState {
  final List<Character> characters;

  const CharacterLoaded({required this.characters});
}

/// Просмотр конкретного персонажа
class CharacterDetail extends CharacterState {
  final Character character;

  const CharacterDetail({required this.character});
}

/// Создание персонажа (мастер)
class CharacterCreating extends CharacterState {
  final CharacterCreationForm form;

  const CharacterCreating({required this.form});
}

/// Отправка формы
class CharacterSubmitting extends CharacterState {
  final CharacterCreationForm form;

  const CharacterSubmitting({required this.form});
}

/// Персонаж успешно создан
class CharacterCreated extends CharacterState {
  final Character character;

  const CharacterCreated({required this.character});
}

/// Персонаж успешно удалён
class CharacterDeleted extends CharacterState {
  final String characterId;

  const CharacterDeleted({required this.characterId});
}

/// Ошибка
class CharacterError extends CharacterState {
  final String message;
  final CharacterState? previousState;

  const CharacterError({
    required this.message,
    this.previousState,
  });
}

/// Форма создания персонажа
class CharacterCreationForm {
  final int currentStep;
  final DndClass? selectedClass;
  final DndRace? selectedRace;
  final AbilityScores abilityScores;
  final String name;
  final String backstory;
  final List<String> validationErrors;

  const CharacterCreationForm({
    this.currentStep = 0,
    this.selectedClass,
    this.selectedRace,
    this.abilityScores = const AbilityScores(),
    this.name = '',
    this.backstory = '',
    this.validationErrors = const [],
  });

  CharacterCreationForm copyWith({
    int? currentStep,
    DndClass? selectedClass,
    DndRace? selectedRace,
    AbilityScores? abilityScores,
    String? name,
    String? backstory,
    List<String>? validationErrors,
  }) {
    return CharacterCreationForm(
      currentStep: currentStep ?? this.currentStep,
      selectedClass: selectedClass ?? this.selectedClass,
      selectedRace: selectedRace ?? this.selectedRace,
      abilityScores: abilityScores ?? this.abilityScores,
      name: name ?? this.name,
      backstory: backstory ?? this.backstory,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }

  /// Шаги мастера
  static const int totalSteps = 4;
  static const int classStep = 0;
  static const int raceStep = 1;
  static const int abilitiesStep = 2;
  static const int backstoryStep = 3;

  /// Можно ли перейти к следующему шагу
  bool get canProceed => switch (currentStep) {
      classStep => selectedClass != null,
      raceStep => selectedRace != null,
      abilitiesStep => _isAbilityScoresValid,
      backstoryStep => name.isNotEmpty,
      _ => false,
    };

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
  String get currentStepTitle => switch (currentStep) {
      classStep => 'Выберите класс',
      raceStep => 'Выберите расу',
      abilitiesStep => 'Распределите характеристики',
      backstoryStep => 'Имя и предыстория',
      _ => '',
    };

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
  CreateCharacterRequest toRequest() => CreateCharacterRequest(
      name: name.trim(),
      characterClass: selectedClass!.id,
      race: selectedRace!.id,
      abilityScores: abilityScoresWithRacialBonus,
      backstory: backstory.trim().isEmpty ? null : backstory.trim(),
    );
}
