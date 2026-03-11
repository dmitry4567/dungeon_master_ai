import 'dice_result.dart';
import 'world_state.dart';

/// Ответ DM (полный, не стриминг)
class DmResponseMessage {
  final String content;
  final DiceResult? diceRequired;
  final StateDelta? stateDelta;
  final DateTime timestamp;

  DmResponseMessage({
    required this.content,
    required this.timestamp,
    this.diceRequired,
    this.stateDelta,
  });

  factory DmResponseMessage.fromJson(Map<String, dynamic> json) {
    return DmResponseMessage(
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      diceRequired: json['dice_required'] != null
          ? DiceResult.fromJson(json['dice_required'] as Map<String, dynamic>)
          : null,
      stateDelta: json['state_delta'] != null
          ? StateDelta.fromJson(json['state_delta'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (diceRequired != null) 'dice_required': diceRequired!.toJson(),
      if (stateDelta != null) 'state_delta': stateDelta!.toJson(),
    };
  }
}

/// Запрос на бросок кубиков через WS
class DiceRequestMessage {
  final DiceResult dice;

  DiceRequestMessage({required this.dice});

  factory DiceRequestMessage.fromJson(Map<String, dynamic> json) {
    return DiceRequestMessage(
      dice: DiceResult.fromJson(json['dice'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dice': dice.toJson(),
    };
  }
}

/// Обновление состояния мира через WS
class StateUpdateMessage {
  final WorldState worldState;

  StateUpdateMessage({required this.worldState});

  factory StateUpdateMessage.fromJson(Map<String, dynamic> json) {
    return StateUpdateMessage(
      worldState: WorldState.fromJson(json['world_state'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'world_state': worldState.toJson(),
    };
  }
}

/// Уведомление о присоединении игрока
class PlayerJoinedMessage {
  final String playerId;
  final String playerName;

  PlayerJoinedMessage({
    required this.playerId,
    required this.playerName,
  });

  factory PlayerJoinedMessage.fromJson(Map<String, dynamic> json) {
    return PlayerJoinedMessage(
      playerId: json['player_id'] as String,
      playerName: json['player_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'player_name': playerName,
    };
  }
}

/// Уведомление об уходе игрока
class PlayerLeftMessage {
  final String playerId;

  PlayerLeftMessage({required this.playerId});

  factory PlayerLeftMessage.fromJson(Map<String, dynamic> json) {
    return PlayerLeftMessage(
      playerId: json['player_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
    };
  }
}

/// Сообщение об ошибке
class ErrorMessage {
  final String message;
  final String? code;

  ErrorMessage({required this.message, this.code});

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    return ErrorMessage(
      message: json['message'] as String,
      code: json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (code != null) 'code': code,
    };
  }
}

/// Ответ синхронизации
class SyncResponseMessage {
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> worldState;

  SyncResponseMessage({
    required this.messages,
    required this.worldState,
  });

  factory SyncResponseMessage.fromJson(Map<String, dynamic> json) {
    return SyncResponseMessage(
      messages: (json['messages'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      worldState: json['world_state'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messages': messages,
      'world_state': worldState,
    };
  }
}

/// Системное сообщение
class SystemMessage {
  final String event;
  final Map<String, dynamic>? data;
  final DateTime? timestamp;

  SystemMessage({required this.event, this.data, this.timestamp});

  factory SystemMessage.fromJson(Map<String, dynamic> json) {
    return SystemMessage(
      event: json['event'] as String,
      data: json['data'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event': event,
      if (data != null) 'data': data,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }
}

/// Дельта изменения состояния мира
class StateDelta {
  final List<String> eventsOccurred;
  final String? locationChanged;
  final String? sceneCompleted;
  final Map<String, bool> flagsChanged;
  final String? actChanged;
  final bool? combatActive;
  final List<String> itemsAcquired;
  final List<String> conditionsApplied;

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

  factory StateDelta.fromJson(Map<String, dynamic> json) {
    return StateDelta(
      eventsOccurred: (json['events_occurred'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      locationChanged: json['location_changed'] as String?,
      sceneCompleted: json['scene_completed'] as String?,
      flagsChanged: (json['flags_changed'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value as bool)) ??
          {},
      actChanged: json['act_changed'] as String?,
      combatActive: json['combat_active'] as bool?,
      itemsAcquired: (json['items_acquired'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      conditionsApplied: (json['conditions_applied'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (eventsOccurred.isNotEmpty) 'events_occurred': eventsOccurred,
      if (locationChanged != null) 'location_changed': locationChanged,
      if (sceneCompleted != null) 'scene_completed': sceneCompleted,
      if (flagsChanged.isNotEmpty) 'flags_changed': flagsChanged,
      if (actChanged != null) 'act_changed': actChanged,
      if (combatActive != null) 'combat_active': combatActive,
      if (itemsAcquired.isNotEmpty) 'items_acquired': itemsAcquired,
      if (conditionsApplied.isNotEmpty) 'conditions_applied': conditionsApplied,
    };
  }
}
