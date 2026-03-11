/// Характеристики персонажа D&D 5e
class AbilityScores {
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  const AbilityScores({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
  });

  factory AbilityScores.fromJson(Map<String, dynamic> json) {
    return AbilityScores(
      strength: (json['strength'] as num?)?.toInt() ?? 10,
      dexterity: (json['dexterity'] as num?)?.toInt() ?? 10,
      constitution: (json['constitution'] as num?)?.toInt() ?? 10,
      intelligence: (json['intelligence'] as num?)?.toInt() ?? 10,
      wisdom: (json['wisdom'] as num?)?.toInt() ?? 10,
      charisma: (json['charisma'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strength': strength,
      'dexterity': dexterity,
      'constitution': constitution,
      'intelligence': intelligence,
      'wisdom': wisdom,
      'charisma': charisma,
    };
  }


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
  AbilityScores copyWith({
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
  }) {
    return AbilityScores(
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      constitution: constitution ?? this.constitution,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
    );
  }

  /// Создать копию с изменённой характеристикой (по названию)
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
