import 'package:freezed_annotation/freezed_annotation.dart';

part 'scenario_content.freezed.dart';
part 'scenario_content.g.dart';

/// Scene within an act
@freezed
class Scene with _$Scene {
  const factory Scene({
    required String id,
    required bool mandatory,
    required String descriptionForAi,
    required List<String> dmHints,
    required List<String> possibleOutcomes,
  }) = _Scene;

  factory Scene.fromJson(Map<String, dynamic> json) => _$SceneFromJson(json);
}

/// Act in a scenario
@freezed
class Act with _$Act {
  const factory Act({
    required String id,
    required String entryCondition,
    required List<String> exitConditions,
    required List<Scene> scenes,
  }) = _Act;

  factory Act.fromJson(Map<String, dynamic> json) => _$ActFromJson(json);
}

/// Non-player character
@freezed
class Npc with _$Npc {
  const factory Npc({
    required String id,
    required String name,
    required String role, // ally, enemy, neutral, quest_giver, antagonist
    required String personality,
    required String speechStyle,
    required List<String> secrets,
    required String motivation,
  }) = _Npc;

  factory Npc.fromJson(Map<String, dynamic> json) => _$NpcFromJson(json);
}

/// Location in the scenario
@freezed
class Location with _$Location {
  const factory Location({
    required String id,
    required String name,
    required String atmosphere,
    required List<dynamic> rooms,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
}

/// Complete scenario content
@freezed
class ScenarioContent with _$ScenarioContent {
  const factory ScenarioContent({
    required String tone,
    required String difficulty,
    required int playersMin,
    required int playersMax,
    required String worldLore,
    required List<Act> acts,
    required List<Npc> npcs,
    required List<Location> locations,
  }) = _ScenarioContent;

  factory ScenarioContent.fromJson(Map<String, dynamic> json) =>
      _$ScenarioContentFromJson(json);
}
