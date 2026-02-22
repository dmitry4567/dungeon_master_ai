import 'dart:convert';

import '../models/ability_scores.dart';
import '../models/character.dart';

/// Модель для кэширования персонажа в SQLite
class CachedCharacter {
  CachedCharacter({
    required this.id,
    required this.name,
    required this.characterClass,
    required this.race,
    required this.level,
    required this.abilityScoresJson,
    this.backstory,
    required this.createdAt,
    this.updatedAt,
    required this.cachedAt,
  });

  /// Создать из Character
  factory CachedCharacter.fromCharacter(Character character) {
    return CachedCharacter(
      id: character.id,
      name: character.name,
      characterClass: character.characterClass,
      race: character.race,
      level: character.level,
      abilityScoresJson: jsonEncode(character.abilityScores.toJson()),
      backstory: character.backstory,
      createdAt: character.createdAt,
      updatedAt: character.updatedAt,
      cachedAt: DateTime.now(),
    );
  }

  /// Создать из Map (SQLite row)
  factory CachedCharacter.fromMap(Map<String, dynamic> map) {
    return CachedCharacter(
      id: map['id'] as String,
      name: map['name'] as String,
      characterClass: map['character_class'] as String,
      race: map['race'] as String,
      level: map['level'] as int,
      abilityScoresJson: map['ability_scores_json'] as String,
      backstory: map['backstory'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      cachedAt: DateTime.parse(map['cached_at'] as String),
    );
  }

  final String id;
  final String name;
  final String characterClass;
  final String race;
  final int level;
  final String abilityScoresJson;
  final String? backstory;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime cachedAt;

  /// Конвертировать в Character
  Character toCharacter() {
    return Character(
      id: id,
      name: name,
      characterClass: characterClass,
      race: race,
      level: level,
      abilityScores: AbilityScores.fromJson(
        jsonDecode(abilityScoresJson) as Map<String, dynamic>,
      ),
      backstory: backstory,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Конвертировать в Map для SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'character_class': characterClass,
      'race': race,
      'level': level,
      'ability_scores_json': abilityScoresJson,
      'backstory': backstory,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'cached_at': cachedAt.toIso8601String(),
    };
  }

  /// Проверить, не устарел ли кэш (по умолчанию 1 час)
  bool isStale({Duration maxAge = const Duration(hours: 1)}) {
    return DateTime.now().difference(cachedAt) > maxAge;
  }
}

/// SQL для создания таблицы персонажей
const createCharactersTableSql = '''
CREATE TABLE IF NOT EXISTS characters (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  character_class TEXT NOT NULL,
  race TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  ability_scores_json TEXT NOT NULL,
  backstory TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  cached_at TEXT NOT NULL
)
''';
