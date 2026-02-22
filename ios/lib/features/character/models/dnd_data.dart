import 'package:freezed_annotation/freezed_annotation.dart';

part 'dnd_data.freezed.dart';
part 'dnd_data.g.dart';

/// Класс D&D 5e
@freezed
class DndClass with _$DndClass {
  const factory DndClass({
    required String id,
    required String name,
    required String nameRu,
    required String hitDie,
    required List<String> primaryAbilities,
    required List<String> savingThrows,
    required String description,
    required String descriptionRu,
    String? iconEmoji,
  }) = _DndClass;

  factory DndClass.fromJson(Map<String, dynamic> json) =>
      _$DndClassFromJson(json);
}

/// Раса D&D 5e
@freezed
class DndRace with _$DndRace {
  const factory DndRace({
    required String id,
    required String name,
    required String nameRu,
    required Map<String, int> abilityBonuses,
    required int speed,
    required String description,
    required String descriptionRu,
    String? iconEmoji,
  }) = _DndRace;

  factory DndRace.fromJson(Map<String, dynamic> json) =>
      _$DndRaceFromJson(json);
}
