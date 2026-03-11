import 'ability_scores.dart';

/// Модель персонажа D&D 5e
class Character {
  final String id;
  final String name;
  final String characterClass;
  final String race;
  final AbilityScores abilityScores;
  final DateTime createdAt;
  final int level;
  final String? backstory;
  final DateTime? updatedAt;

  const Character({
    required this.id,
    required this.name,
    required this.characterClass,
    required this.race,
    required this.abilityScores,
    required this.createdAt,
    this.level = 1,
    this.backstory,
    this.updatedAt,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String,
      name: json['name'] as String,
      characterClass: json['class'] as String,
      race: json['race'] as String,
      abilityScores: AbilityScores.fromJson(json['ability_scores'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      level: (json['level'] as num?)?.toInt() ?? 1,
      backstory: json['backstory'] as String?,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'class': characterClass,
      'race': race,
      'ability_scores': abilityScores.toJson(),
      'created_at': createdAt.toIso8601String(),
      'level': level,
      if (backstory != null) 'backstory': backstory,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

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

  int _getHitDie(String className) => switch (className.toLowerCase()) {
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

/// Запрос на создание персонажа
class CreateCharacterRequest {
  final String name;
  final String characterClass;
  final String race;
  final AbilityScores abilityScores;
  final String? backstory;

  const CreateCharacterRequest({
    required this.name,
    required this.characterClass,
    required this.race,
    required this.abilityScores,
    this.backstory,
  });

  factory CreateCharacterRequest.fromJson(Map<String, dynamic> json) {
    return CreateCharacterRequest(
      name: json['name'] as String,
      characterClass: json['character_class'] as String,
      race: json['race'] as String,
      abilityScores: AbilityScores.fromJson(json['ability_scores'] as Map<String, dynamic>),
      backstory: json['backstory'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'character_class': characterClass,
      'race': race,
      'ability_scores': abilityScores.toJson(),
      if (backstory != null) 'backstory': backstory,
    };
  }
}

/// Запрос на обновление персонажа
class UpdateCharacterRequest {
  final String? name;
  final String? backstory;

  const UpdateCharacterRequest({
    this.name,
    this.backstory,
  });

  factory UpdateCharacterRequest.fromJson(Map<String, dynamic> json) {
    return UpdateCharacterRequest(
      name: json['name'] as String?,
      backstory: json['backstory'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (backstory != null) 'backstory': backstory,
    };
  }
}
