/// Состояние игрового мира
class WorldState {
  final String currentAct;
  final String? currentScene;
  final String? currentLocation;
  final List<String> completedScenes;
  final Map<String, dynamic> flags;
  final bool combatActive;

  const WorldState({
    this.currentAct = 'act_1',
    this.currentScene,
    this.currentLocation,
    this.completedScenes = const [],
    this.flags = const {},
    this.combatActive = false,
  });

  factory WorldState.fromJson(Map<String, dynamic> json) {
    return WorldState(
      currentAct: json['current_act'] as String? ?? 'act_1',
      currentScene: json['current_scene'] as String?,
      currentLocation: json['current_location'] as String?,
      completedScenes: (json['completed_scenes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      flags: json['flags'] as Map<String, dynamic>? ?? {},
      combatActive: json['combat_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_act': currentAct,
      if (currentScene != null) 'current_scene': currentScene,
      if (currentLocation != null) 'current_location': currentLocation,
      'completed_scenes': completedScenes,
      'flags': flags,
      'combat_active': combatActive,
    };
  }
}

/// Игровая сессия
class GameSession {
  final String id;
  final String roomId;
  final WorldState worldState;
  final DateTime startedAt;
  final DateTime? endedAt;

  const GameSession({
    required this.id,
    required this.roomId,
    required this.worldState,
    required this.startedAt,
    this.endedAt,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      worldState: WorldState.fromJson(json['world_state'] as Map<String, dynamic>),
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'world_state': worldState.toJson(),
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
    };
  }
}

/// Статус сессии
class SessionStatus {
  final String sessionId;
  final bool isActive;
  final String? currentAct;
  final String? currentScene;
  final String? currentLocation;
  final bool combatActive;
  final int playerCount;
  final int messageCount;

  const SessionStatus({
    required this.sessionId,
    required this.isActive,
    this.currentAct,
    this.currentScene,
    this.currentLocation,
    this.combatActive = false,
    this.playerCount = 0,
    this.messageCount = 0,
  });

  factory SessionStatus.fromJson(Map<String, dynamic> json) {
    return SessionStatus(
      sessionId: json['session_id'] as String,
      isActive: json['is_active'] as bool,
      currentAct: json['current_act'] as String?,
      currentScene: json['current_scene'] as String?,
      currentLocation: json['current_location'] as String?,
      combatActive: json['combat_active'] as bool? ?? false,
      playerCount: (json['player_count'] as num?)?.toInt() ?? 0,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'is_active': isActive,
      if (currentAct != null) 'current_act': currentAct,
      if (currentScene != null) 'current_scene': currentScene,
      if (currentLocation != null) 'current_location': currentLocation,
      'combat_active': combatActive,
      'player_count': playerCount,
      'message_count': messageCount,
    };
  }
}
