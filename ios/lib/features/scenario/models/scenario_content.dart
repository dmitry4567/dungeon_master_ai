class Condition {
  final String condition;
  final String description;

  const Condition({
    required this.condition,
    required this.description,
  });

  factory Condition.fromJson(Map<String, dynamic> json) {
    return Condition(
      condition: json['condition'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'description': description,
    };
  }
}

/// Scene within an act
class Scene {
  final String id;
  final String name;
  final bool mandatory;
  final String descriptionForAi;
  final List<String> dmHints;
  final List<String> possibleOutcomes;

  const Scene({
    required this.id,
    required this.name,
    required this.mandatory,
    required this.descriptionForAi,
    required this.dmHints,
    required this.possibleOutcomes,
  });

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'] as String,
      name: json['name'] as String,
      mandatory: json['mandatory'] as bool,
      descriptionForAi: json['description_for_ai'] as String,
      dmHints: (json['dm_hints'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      possibleOutcomes: (json['possible_outcomes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mandatory': mandatory,
      'description_for_ai': descriptionForAi,
      'dm_hints': dmHints,
      'possible_outcomes': possibleOutcomes,
    };
  }
}

/// Act in a scenario
class Act {
  final String id;
  final String name;
  final Condition entryCondition;
  final List<Condition> exitConditions;
  final List<Scene> scenes;

  const Act({
    required this.id,
    required this.name,
    required this.entryCondition,
    required this.exitConditions,
    required this.scenes,
  });

  factory Act.fromJson(Map<String, dynamic> json) {
    return Act(
      id: json['id'] as String,
      name: json['name'] as String,
      entryCondition: Condition.fromJson(json['entry_condition'] as Map<String, dynamic>),
      exitConditions: (json['exit_conditions'] as List<dynamic>)
          .map((e) => Condition.fromJson(e as Map<String, dynamic>))
          .toList(),
      scenes: (json['scenes'] as List<dynamic>)
          .map((e) => Scene.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'entry_condition': entryCondition.toJson(),
      'exit_conditions': exitConditions.map((e) => e.toJson()).toList(),
      'scenes': scenes.map((e) => e.toJson()).toList(),
    };
  }
}

/// Non-player character
class Npc {
  final String id;
  final String name;
  final String role;
  final String personality;
  final String speechStyle;
  final List<String> secrets;
  final String motivation;

  const Npc({
    required this.id,
    required this.name,
    required this.role,
    required this.personality,
    required this.speechStyle,
    required this.secrets,
    required this.motivation,
  });

  factory Npc.fromJson(Map<String, dynamic> json) {
    return Npc(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      personality: json['personality'] as String,
      speechStyle: json['speech_style'] as String,
      secrets: (json['secrets'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      motivation: json['motivation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'personality': personality,
      'speech_style': speechStyle,
      'secrets': secrets,
      'motivation': motivation,
    };
  }
}

/// Location in the scenario
class Location {
  final String id;
  final String name;
  final String atmosphere;
  final List<dynamic> rooms;

  const Location({
    required this.id,
    required this.name,
    required this.atmosphere,
    required this.rooms,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      atmosphere: json['atmosphere'] as String,
      rooms: json['rooms'] as List<dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'atmosphere': atmosphere,
      'rooms': rooms,
    };
  }
}

/// Flag definition
class Flag {
  final String id;
  final String name;
  final String description;

  const Flag({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Flag.fromJson(Map<String, dynamic> json) {
    return Flag(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}

/// Complete scenario content
class ScenarioContent {
  final String tone;
  final String difficulty;
  final int playersMin;
  final int playersMax;
  final String worldLore;
  final List<Act> acts;
  final List<Npc> npcs;
  final List<Location> locations;
  final List<Flag> flags;

  const ScenarioContent({
    required this.tone,
    required this.difficulty,
    required this.playersMin,
    required this.playersMax,
    required this.worldLore,
    required this.acts,
    required this.npcs,
    required this.locations,
    this.flags = const [],
  });

  factory ScenarioContent.fromJson(Map<String, dynamic> json) {
    return ScenarioContent(
      tone: json['tone'] as String,
      difficulty: json['difficulty'] as String,
      playersMin: (json['players_min'] as num).toInt(),
      playersMax: (json['players_max'] as num).toInt(),
      worldLore: json['world_lore'] as String,
      acts: (json['acts'] as List<dynamic>)
          .map((e) => Act.fromJson(e as Map<String, dynamic>))
          .toList(),
      npcs: (json['npcs'] as List<dynamic>)
          .map((e) => Npc.fromJson(e as Map<String, dynamic>))
          .toList(),
      locations: (json['locations'] as List<dynamic>)
          .map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList(),
      flags: (json['flags'] as List<dynamic>?)
              ?.map((e) => Flag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tone': tone,
      'difficulty': difficulty,
      'players_min': playersMin,
      'players_max': playersMax,
      'world_lore': worldLore,
      'acts': acts.map((e) => e.toJson()).toList(),
      'npcs': npcs.map((e) => e.toJson()).toList(),
      'locations': locations.map((e) => e.toJson()).toList(),
      'flags': flags.map((e) => e.toJson()).toList(),
    };
  }
}
