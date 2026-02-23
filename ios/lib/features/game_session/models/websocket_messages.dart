import 'package:json_annotation/json_annotation.dart';

import 'dice_result.dart';
import 'world_state.dart';

part 'websocket_messages.g.dart';

/// Ответ DM (полный, не стриминг)
@JsonSerializable()
class DmResponseMessage {
  DmResponseMessage({
    required this.content,
    this.diceRequired,
    this.stateDelta,
    required this.timestamp,
  });

  factory DmResponseMessage.fromJson(Map<String, dynamic> json) =>
      _$DmResponseMessageFromJson(json);

  final String content;
  @JsonKey(name: 'dice_required')
  final DiceResult? diceRequired;
  @JsonKey(name: 'state_delta')
  final StateDelta? stateDelta;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => _$DmResponseMessageToJson(this);
}

/// Запрос на бросок кубиков через WS
@JsonSerializable()
class DiceRequestMessage {
  DiceRequestMessage({required this.dice});

  factory DiceRequestMessage.fromJson(Map<String, dynamic> json) =>
      _$DiceRequestMessageFromJson(json);

  final DiceResult dice;

  Map<String, dynamic> toJson() => _$DiceRequestMessageToJson(this);
}

/// Обновление состояния мира через WS
@JsonSerializable()
class StateUpdateMessage {
  StateUpdateMessage({required this.worldState});

  factory StateUpdateMessage.fromJson(Map<String, dynamic> json) =>
      _$StateUpdateMessageFromJson(json);

  @JsonKey(name: 'world_state')
  final WorldState worldState;

  Map<String, dynamic> toJson() => _$StateUpdateMessageToJson(this);
}

/// Уведомление о присоединении игрока
@JsonSerializable()
class PlayerJoinedMessage {
  PlayerJoinedMessage({
    required this.playerId,
    required this.playerName,
  });

  factory PlayerJoinedMessage.fromJson(Map<String, dynamic> json) =>
      _$PlayerJoinedMessageFromJson(json);

  @JsonKey(name: 'player_id')
  final String playerId;
  @JsonKey(name: 'player_name')
  final String playerName;

  Map<String, dynamic> toJson() => _$PlayerJoinedMessageToJson(this);
}

/// Уведомление об уходе игрока
@JsonSerializable()
class PlayerLeftMessage {
  PlayerLeftMessage({required this.playerId});

  factory PlayerLeftMessage.fromJson(Map<String, dynamic> json) =>
      _$PlayerLeftMessageFromJson(json);

  @JsonKey(name: 'player_id')
  final String playerId;

  Map<String, dynamic> toJson() => _$PlayerLeftMessageToJson(this);
}

/// Сообщение об ошибке
@JsonSerializable()
class ErrorMessage {
  ErrorMessage({required this.message, this.code});

  factory ErrorMessage.fromJson(Map<String, dynamic> json) =>
      _$ErrorMessageFromJson(json);

  final String message;
  final String? code;

  Map<String, dynamic> toJson() => _$ErrorMessageToJson(this);
}

/// Ответ синхронизации
@JsonSerializable()
class SyncResponseMessage {
  SyncResponseMessage({
    required this.messages,
    required this.worldState,
  });

  factory SyncResponseMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncResponseMessageFromJson(json);

  final List<Map<String, dynamic>> messages;
  @JsonKey(name: 'world_state')
  final Map<String, dynamic> worldState;

  Map<String, dynamic> toJson() => _$SyncResponseMessageToJson(this);
}

/// Системное сообщение
@JsonSerializable()
class SystemMessage {
  SystemMessage({required this.event, this.data, this.timestamp});

  factory SystemMessage.fromJson(Map<String, dynamic> json) =>
      _$SystemMessageFromJson(json);

  final String event;
  final Map<String, dynamic>? data;
  final DateTime? timestamp;

  Map<String, dynamic> toJson() => _$SystemMessageToJson(this);
}

/// Дельта изменения состояния мира
@JsonSerializable()
class StateDelta {
  StateDelta({
    this.eventsOccurred = const [],
    this.locationChanged,
    this.sceneCompleted,
    this.flagsChanged = const {},
    this.actChanged,
    this.combatActive,
    this.itemsAcquired = const [],
    this.conditionsApplied = const [],
  });

  factory StateDelta.fromJson(Map<String, dynamic> json) =>
      _$StateDeltaFromJson(json);

  @JsonKey(name: 'events_occurred')
  final List<String> eventsOccurred;
  @JsonKey(name: 'location_changed')
  final String? locationChanged;
  @JsonKey(name: 'scene_completed')
  final String? sceneCompleted;
  @JsonKey(name: 'flags_changed')
  final Map<String, bool> flagsChanged;
  @JsonKey(name: 'act_changed')
  final String? actChanged;
  @JsonKey(name: 'combat_active')
  final bool? combatActive;
  @JsonKey(name: 'items_acquired')
  final List<String> itemsAcquired;
  @JsonKey(name: 'conditions_applied')
  final List<String> conditionsApplied;

  Map<String, dynamic> toJson() => _$StateDeltaToJson(this);
}
