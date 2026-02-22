import 'package:freezed_annotation/freezed_annotation.dart';

part 'ability_scores.freezed.dart';
part 'ability_scores.g.dart';

/// Характеристики персонажа D&D 5e
@freezed
class AbilityScores with _$AbilityScores {

  const factory AbilityScores({
    @Default(10) int strength,
    @Default(10) int dexterity,
    @Default(10) int constitution,
    @Default(10) int intelligence,
    @Default(10) int wisdom,
    @Default(10) int charisma,
  }) = _AbilityScores;
  const AbilityScores._();

  factory AbilityScores.fromJson(Map<String, dynamic> json) =>
      _$AbilityScoresFromJson(json);

  /// Расчёт модификатора по правилам D&D 5e: floor((score - 10) / 2)
  /// Используем floor division для корректной обработки отрицательных чисел
  static int calculateModifier(int score) {
    final diff = score - 10;
    // Floor division: для отрицательных нечётных чисел округляем вниз
    if (diff < 0 && diff.isOdd) {
      return (diff ~/ 2) - 1;
    }
    return diff ~/ 2;
  }

  /// Модификатор силы
  int get strengthModifier => calculateModifier(strength);

  /// Модификатор ловкости
  int get dexterityModifier => calculateModifier(dexterity);

  /// Модификатор телосложения
  int get constitutionModifier => calculateModifier(constitution);

  /// Модификатор интеллекта
  int get intelligenceModifier => calculateModifier(intelligence);

  /// Модификатор мудрости
  int get wisdomModifier => calculateModifier(wisdom);

  /// Модификатор харизмы
  int get charismaModifier => calculateModifier(charisma);

  /// Получить модификатор по названию характеристики
  int getModifier(String ability) => switch (ability.toLowerCase()) {
      'strength' || 'str' || 'сила' => strengthModifier,
      'dexterity' || 'dex' || 'ловкость' => dexterityModifier,
      'constitution' || 'con' || 'телосложение' => constitutionModifier,
      'intelligence' || 'int' || 'интеллект' => intelligenceModifier,
      'wisdom' || 'wis' || 'мудрость' => wisdomModifier,
      'charisma' || 'cha' || 'харизма' => charismaModifier,
      _ => 0,
    };

  /// Получить значение характеристики по названию
  int getValue(String ability) => switch (ability.toLowerCase()) {
      'strength' || 'str' || 'сила' => strength,
      'dexterity' || 'dex' || 'ловкость' => dexterity,
      'constitution' || 'con' || 'телосложение' => constitution,
      'intelligence' || 'int' || 'интеллект' => intelligence,
      'wisdom' || 'wis' || 'мудрость' => wisdom,
      'charisma' || 'cha' || 'харизма' => charisma,
      _ => 0,
    };

  /// Сумма всех характеристик
  int get total =>
      strength + dexterity + constitution + intelligence + wisdom + charisma;

  /// Список всех значений
  List<int> get values =>
      [strength, dexterity, constitution, intelligence, wisdom, charisma];

  /// Создать копию с изменённой характеристикой
  AbilityScores withAbility(String ability, int value) => switch (ability.toLowerCase()) {
      'strength' || 'str' || 'сила' => copyWith(strength: value),
      'dexterity' || 'dex' || 'ловкость' => copyWith(dexterity: value),
      'constitution' || 'con' || 'телосложение' => copyWith(constitution: value),
      'intelligence' || 'int' || 'интеллект' => copyWith(intelligence: value),
      'wisdom' || 'wis' || 'мудрость' => copyWith(wisdom: value),
      'charisma' || 'cha' || 'харизма' => copyWith(charisma: value),
      _ => this,
    };
}

/// Названия характеристик для UI
abstract final class AbilityNames {
  static const Map<String, String> ruNames = {
    'strength': 'Сила',
    'dexterity': 'Ловкость',
    'constitution': 'Телосложение',
    'intelligence': 'Интеллект',
    'wisdom': 'Мудрость',
    'charisma': 'Харизма',
  };

  static const Map<String, String> shortNames = {
    'strength': 'СИЛ',
    'dexterity': 'ЛОВ',
    'constitution': 'ТЕЛ',
    'intelligence': 'ИНТ',
    'wisdom': 'МДР',
    'charisma': 'ХАР',
  };

  static const List<String> all = [
    'strength',
    'dexterity',
    'constitution',
    'intelligence',
    'wisdom',
    'charisma',
  ];
}
