import 'package:freezed_annotation/freezed_annotation.dart';

part 'dice_result.freezed.dart';
part 'dice_result.g.dart';

/// Результат броска кубиков
@freezed
class DiceResult with _$DiceResult {
  const factory DiceResult({
    required String type, // d20, d6, 2d6, etc.
    @JsonKey(name: 'base_roll') int? baseRoll,
    int? modifier,
    int? total,
    int? dc,
    String? skill,
    String? ability,
    bool? success,
    @JsonKey(name: 'damage_type') String? damageType,
    @JsonKey(name: 'roll_type') String? rollType, // attack, save, check, damage
    bool? advantage,
    bool? disadvantage,
    bool? critical,
  }) = _DiceResult;

  factory DiceResult.fromJson(Map<String, dynamic> json) =>
      _$DiceResultFromJson(json);
}

/// Запрос на бросок кубиков
@freezed
class DiceRequest with _$DiceRequest {
  const factory DiceRequest({
    required String type, // d20, 2d6, etc.
    int? modifier,
    int? dc,
    String? skill,
    String? ability,
    @JsonKey(name: 'damage_type') String? damageType,
    @JsonKey(name: 'roll_type') String? rollType, // attack, save, check, damage
    bool? advantage,
    bool? disadvantage,
    String? description,
  }) = _DiceRequest;

  factory DiceRequest.fromJson(Map<String, dynamic> json) =>
      _$DiceRequestFromJson(json);
}
