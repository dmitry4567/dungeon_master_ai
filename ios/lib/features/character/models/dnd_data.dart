/// Класс D&D 5e
class DndClass {
  final String id;
  final String name;
  final String nameRu;
  final String hitDie;
  final List<String> primaryAbilities;
  final List<String> savingThrows;
  final String description;
  final String descriptionRu;
  final String? iconEmoji;

  const DndClass({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.hitDie,
    required this.primaryAbilities,
    required this.savingThrows,
    required this.description,
    required this.descriptionRu,
    this.iconEmoji,
  });

  factory DndClass.fromJson(Map<String, dynamic> json) {
    return DndClass(
      id: json['id'] as String,
      name: json['name'] as String,
      nameRu: json['name_ru'] as String,
      hitDie: json['hit_die'] as String,
      primaryAbilities: (json['primary_abilities'] as List<dynamic>?)?.cast<String>() ?? [],
      savingThrows: (json['saving_throws'] as List<dynamic>?)?.cast<String>() ?? [],
      description: json['description'] as String,
      descriptionRu: json['description_ru'] as String,
      iconEmoji: json['icon_emoji'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ru': nameRu,
      'hit_die': hitDie,
      'primary_abilities': primaryAbilities,
      'saving_throws': savingThrows,
      'description': description,
      'description_ru': descriptionRu,
      if (iconEmoji != null) 'icon_emoji': iconEmoji,
    };
  }
}

/// Раса D&D 5e
class DndRace {
  final String id;
  final String name;
  final String nameRu;
  final Map<String, int> abilityBonuses;
  final int speed;
  final String description;
  final String descriptionRu;
  final String? iconEmoji;

  const DndRace({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.abilityBonuses,
    required this.speed,
    required this.description,
    required this.descriptionRu,
    this.iconEmoji,
  });

  factory DndRace.fromJson(Map<String, dynamic> json) {
    return DndRace(
      id: json['id'] as String,
      name: json['name'] as String,
      nameRu: json['name_ru'] as String,
      abilityBonuses: (json['ability_bonuses'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ) ?? {},
      speed: (json['speed'] as num?)?.toInt() ?? 0,
      description: json['description'] as String,
      descriptionRu: json['description_ru'] as String,
      iconEmoji: json['icon_emoji'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ru': nameRu,
      'ability_bonuses': abilityBonuses,
      'speed': speed,
      'description': description,
      'description_ru': descriptionRu,
      if (iconEmoji != null) 'icon_emoji': iconEmoji,
    };
  }
}
