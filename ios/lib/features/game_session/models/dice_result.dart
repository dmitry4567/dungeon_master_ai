/// Результат броска кубиков
class DiceResult {
  final String type;
  final int? baseRoll;
  final int? modifier;
  final int? total;
  final int? dc;
  final String? skill;
  final String? ability;
  final bool? success;
  final String? damageType;
  final String? rollType;
  final bool? advantage;
  final bool? disadvantage;
  final bool? critical;

  const DiceResult({
    required this.type,
    this.baseRoll,
    this.modifier,
    this.total,
    this.dc,
    this.skill,
    this.ability,
    this.success,
    this.damageType,
    this.rollType,
    this.advantage,
    this.disadvantage,
    this.critical,
  });

  factory DiceResult.fromJson(Map<String, dynamic> json) {
    return DiceResult(
      type: json['type'] as String,
      baseRoll: (json['base_roll'] as num?)?.toInt(),
      modifier: (json['modifier'] as num?)?.toInt(),
      total: (json['total'] as num?)?.toInt(),
      dc: (json['dc'] as num?)?.toInt(),
      skill: json['skill'] as String?,
      ability: json['ability'] as String?,
      success: json['success'] as bool?,
      damageType: json['damage_type'] as String?,
      rollType: json['roll_type'] as String?,
      advantage: json['advantage'] as bool?,
      disadvantage: json['disadvantage'] as bool?,
      critical: json['critical'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (baseRoll != null) 'base_roll': baseRoll,
      if (modifier != null) 'modifier': modifier,
      if (total != null) 'total': total,
      if (dc != null) 'dc': dc,
      if (skill != null) 'skill': skill,
      if (ability != null) 'ability': ability,
      if (success != null) 'success': success,
      if (damageType != null) 'damage_type': damageType,
      if (rollType != null) 'roll_type': rollType,
      if (advantage != null) 'advantage': advantage,
      if (disadvantage != null) 'disadvantage': disadvantage,
      if (critical != null) 'critical': critical,
    };
  }
}

/// Запрос на бросок кубиков от сервера
class DiceRequest {
  final String requestId;
  final String targetPlayerId;
  final String targetPlayerName;
  final String diceType;
  final int numDice;
  final int modifier;
  final int? dc;
  final String? skill;
  final String? reason;

  const DiceRequest({
    required this.requestId,
    required this.targetPlayerId,
    required this.targetPlayerName,
    required this.diceType,
    this.numDice = 1,
    this.modifier = 0,
    this.dc,
    this.skill,
    this.reason,
  });

  factory DiceRequest.fromJson(Map<String, dynamic> json) {
    return DiceRequest(
      requestId: json['request_id'] as String,
      targetPlayerId: json['target_player_id'] as String,
      targetPlayerName: json['target_player_name'] as String,
      diceType: json['dice_type'] as String,
      numDice: (json['num_dice'] as num?)?.toInt() ?? 1,
      modifier: (json['modifier'] as num?)?.toInt() ?? 0,
      dc: (json['dc'] as num?)?.toInt(),
      skill: json['skill'] as String?,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'target_player_id': targetPlayerId,
      'target_player_name': targetPlayerName,
      'dice_type': diceType,
      'num_dice': numDice,
      if (modifier != 0) 'modifier': modifier,
      if (dc != null) 'dc': dc,
      if (skill != null) 'skill': skill,
      if (reason != null) 'reason': reason,
    };
  }
}
