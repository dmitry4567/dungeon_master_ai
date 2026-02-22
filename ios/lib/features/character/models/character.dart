import 'package:freezed_annotation/freezed_annotation.dart';

import 'ability_scores.dart';

part 'character.freezed.dart';
part 'character.g.dart';

/// Модель персонажа D&D 5e
@freezed
class Character with _$Character {
  const Character._();

  const factory Character({
    required String id,
    required String name,
    @JsonKey(name: 'class')
    required String characterClass,
    required String race,
    @Default(1) int level,
    required AbilityScores abilityScores,
    String? backstory,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);

  /// Бонус мастерства по уровню (D&D 5e)
  int get proficiencyBonus => ((level - 1) ~/ 4) + 2;

  /// Максимальное здоровье (упрощённый расчёт)
  int get maxHitPoints {
    final hitDie = _getHitDie(characterClass);
    final conMod = abilityScores.constitutionModifier;
    // Первый уровень: максимум кубика + con mod
    // Остальные уровни: среднее + con mod
    if (level == 1) {
      return hitDie + conMod;
    }
    final averagePerLevel = (hitDie ~/ 2) + 1;
    return hitDie + conMod + (level - 1) * (averagePerLevel + conMod);
  }

  int _getHitDie(String className) {
    return switch (className.toLowerCase()) {
      'barbarian' || 'варвар' => 12,
      'fighter' || 'воин' || 'paladin' || 'паладин' || 'ranger' || 'следопыт' =>
        10,
      'bard' ||
      'бард' ||
      'cleric' ||
      'жрец' ||
      'druid' ||
      'друид' ||
      'monk' ||
      'монах' ||
      'rogue' ||
      'плут' ||
      'warlock' ||
      'колдун' =>
        8,
      'sorcerer' || 'чародей' || 'wizard' || 'волшебник' => 6,
      _ => 8,
    };
  }
}

/// Запрос на создание персонажа
@freezed
class CreateCharacterRequest with _$CreateCharacterRequest {
  const factory CreateCharacterRequest({
    required String name,
    required String characterClass,
    required String race,
    required AbilityScores abilityScores,
    String? backstory,
  }) = _CreateCharacterRequest;

  factory CreateCharacterRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCharacterRequestFromJson(json);
}

/// Запрос на обновление персонажа
@freezed
class UpdateCharacterRequest with _$UpdateCharacterRequest {
  const factory UpdateCharacterRequest({
    String? name,
    String? backstory,
  }) = _UpdateCharacterRequest;

  factory UpdateCharacterRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateCharacterRequestFromJson(json);
}
