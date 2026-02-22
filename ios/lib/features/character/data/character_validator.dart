import 'package:injectable/injectable.dart';

import '../models/ability_scores.dart';
import '../models/character.dart';
import 'dnd_reference_data.dart';

/// Валидатор персонажей D&D 5e
@lazySingleton
class CharacterValidator {
  const CharacterValidator();

  /// Валидировать запрос на создание персонажа
  List<String> validate(CreateCharacterRequest request) {
    final errors = <String>[];

    errors.addAll(validateName(request.name));
    errors.addAll(validateClass(request.characterClass));
    errors.addAll(validateRace(request.race));
    errors.addAll(validateAbilityScores(request.abilityScores));

    if (request.backstory != null) {
      errors.addAll(validateBackstory(request.backstory!));
    }

    return errors;
  }

  /// Валидировать имя персонажа
  List<String> validateName(String name) {
    final errors = <String>[];

    if (name.isEmpty) {
      errors.add('Имя персонажа обязательно');
    } else if (name.length < 2) {
      errors.add('Имя должно содержать минимум 2 символа');
    } else if (name.length > 100) {
      errors.add('Имя должно быть не длиннее 100 символов');
    }

    // Проверка на допустимые символы (буквы, пробелы, дефисы, апострофы)
    final validNameRegex = RegExp(r"^[\p{L}\s\-']+$", unicode: true);
    if (name.isNotEmpty && !validNameRegex.hasMatch(name)) {
      errors.add('Имя может содержать только буквы, пробелы, дефисы и апострофы');
    }

    return errors;
  }

  /// Валидировать класс персонажа
  List<String> validateClass(String characterClass) {
    final errors = <String>[];

    if (characterClass.isEmpty) {
      errors.add('Класс персонажа обязателен');
    } else if (DndReferenceData.findClassById(characterClass) == null) {
      errors.add('Недопустимый класс персонажа');
    }

    return errors;
  }

  /// Валидировать расу персонажа
  List<String> validateRace(String race) {
    final errors = <String>[];

    if (race.isEmpty) {
      errors.add('Раса персонажа обязательна');
    } else if (DndReferenceData.findRaceById(race) == null) {
      errors.add('Недопустимая раса персонажа');
    }

    return errors;
  }

  /// Валидировать характеристики персонажа
  List<String> validateAbilityScores(AbilityScores scores) {
    final errors = <String>[];

    // Проверка каждой характеристики
    for (final ability in AbilityNames.all) {
      final value = scores.getValue(ability);
      if (value < DndReferenceData.minAbilityScore) {
        errors.add(
          '${AbilityNames.ruNames[ability]} не может быть меньше ${DndReferenceData.minAbilityScore}',
        );
      }
      if (value > DndReferenceData.maxAbilityScore) {
        errors.add(
          '${AbilityNames.ruNames[ability]} не может быть больше ${DndReferenceData.maxAbilityScore}',
        );
      }
    }

    // Проверка суммы характеристик
    final total = scores.total;
    if (total < DndReferenceData.minTotalAbilityScore) {
      errors.add(
        'Сумма характеристик должна быть не меньше ${DndReferenceData.minTotalAbilityScore} (текущая: $total)',
      );
    }
    if (total > DndReferenceData.maxTotalAbilityScore) {
      errors.add(
        'Сумма характеристик должна быть не больше ${DndReferenceData.maxTotalAbilityScore} (текущая: $total)',
      );
    }

    return errors;
  }

  /// Валидировать предысторию персонажа
  List<String> validateBackstory(String backstory) {
    final errors = <String>[];

    if (backstory.length > 2000) {
      errors.add('Предыстория должна быть не длиннее 2000 символов');
    }

    return errors;
  }

  /// Проверить, валиден ли запрос на создание
  bool isValid(CreateCharacterRequest request) {
    return validate(request).isEmpty;
  }
}

/// Результат валидации с типом ошибки
enum ValidationErrorType {
  name,
  characterClass,
  race,
  abilityScores,
  backstory,
}

/// Структурированная ошибка валидации
class ValidationError {
  const ValidationError({
    required this.type,
    required this.message,
    this.field,
  });

  final ValidationErrorType type;
  final String message;
  final String? field;
}
