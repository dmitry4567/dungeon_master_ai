import '../../character/models/character.dart';
import '../../scenario/models/scenario.dart';

Character? _characterFromJson(Map<String, dynamic>? json) =>
    json == null ? null : Character.fromJson(json);

Map<String, dynamic>? _characterToJson(Character? character) {
  if (character == null) return null;
  return character.toJson();
}

/// Room player in a game room
class RoomPlayer {
  final String id;
  final String userId;
  final String name;
  final String status;
  final bool isHost;
  final Character? character;

  const RoomPlayer({
    required this.id,
    required this.userId,
    required this.name,
    required this.status,
    required this.isHost,
    this.character,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      isHost: json['is_host'] as bool? ?? false,
      character: _characterFromJson(json['character'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'status': status,
      'is_host': isHost,
      if (character != null) 'character': _characterToJson(character),
    };
  }
}

/// Full room detail response
class Room {
  final String id;
  final String name;
  final String status;
  final int maxPlayers;
  final DateTime createdAt;
  final Scenario? scenario;
  final List<RoomPlayer> players;

  const Room({
    required this.id,
    required this.name,
    required this.status,
    required this.maxPlayers,
    required this.createdAt,
    this.scenario,
    this.players = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 5,
      createdAt: DateTime.parse(json['created_at'] as String),
      scenario: json['scenario'] != null 
          ? Scenario.fromJson(json['scenario'] as Map<String, dynamic>) 
          : null,
      players: (json['players'] as List<dynamic>?)
              ?.map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'max_players': maxPlayers,
      'created_at': createdAt.toIso8601String(),
      if (scenario != null) 'scenario': scenario!.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
    };
  }
  /// Count of non-declined players
  int get activePlayerCount =>
      players.where((p) => p.status != 'declined').length;

  /// Check if room is full
  bool get isFull => activePlayerCount >= maxPlayers;

  /// Check if all approved players are ready
  bool get allPlayersReady => players
      .where((p) => p.status != 'declined' && p.status != 'pending')
      .every((p) => p.status == 'ready');

  /// Get the host player
  RoomPlayer? get host => players.where((p) => p.isHost).firstOrNull;

  /// Get pending join requests
  List<RoomPlayer> get pendingRequests =>
      players.where((p) => p.status == 'pending').toList();
}

/// Room summary for list view
class RoomSummary {
  final String id;
  final String name;
  final String scenarioTitle;
  final String hostName;
  final int playerCount;
  final int maxPlayers;
  final String status;
  final bool isCurrentUserPlayer;

  const RoomSummary({
    required this.id,
    required this.name,
    required this.scenarioTitle,
    required this.hostName,
    required this.playerCount,
    required this.maxPlayers,
    required this.status,
    this.isCurrentUserPlayer = false,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    return RoomSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      scenarioTitle: json['scenario_title'] as String,
      hostName: json['host_name'] as String,
      playerCount: (json['player_count'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 5,
      status: json['status'] as String,
      isCurrentUserPlayer: json['is_current_user_player'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scenario_title': scenarioTitle,
      'host_name': hostName,
      'player_count': playerCount,
      'max_players': maxPlayers,
      'status': status,
      'is_current_user_player': isCurrentUserPlayer,
    };
  }
}

/// Request to create a new room
class CreateRoomRequest {
  final String name;
  final String scenarioVersionId;
  final int maxPlayers;
  final String? characterId;

  const CreateRoomRequest({
    required this.name,
    required this.scenarioVersionId,
    this.maxPlayers = 5,
    this.characterId,
  });

  factory CreateRoomRequest.fromJson(Map<String, dynamic> json) {
    return CreateRoomRequest(
      name: json['name'] as String,
      scenarioVersionId: json['scenario_version_id'] as String,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 5,
      characterId: json['character_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scenario_version_id': scenarioVersionId,
      'max_players': maxPlayers,
      if (characterId != null) 'character_id': characterId,
    };
  }
}

/// Request to toggle ready status
class ReadyRequest {
  final bool ready;
  final String? characterId;

  const ReadyRequest({
    required this.ready,
    this.characterId,
  });

  factory ReadyRequest.fromJson(Map<String, dynamic> json) {
    return ReadyRequest(
      ready: json['ready'] as bool,
      characterId: json['character_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ready': ready,
      if (characterId != null) 'character_id': characterId,
    };
  }
}

/// Game session response from start endpoint
class GameSessionResponse {
  final String id;
  final String roomId;
  final Map<String, dynamic> worldState;
  final DateTime startedAt;

  const GameSessionResponse({
    required this.id,
    required this.roomId,
    required this.worldState,
    required this.startedAt,
  });

  factory GameSessionResponse.fromJson(Map<String, dynamic> json) {
    return GameSessionResponse(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      worldState: json['world_state'] as Map<String, dynamic>,
      startedAt: DateTime.parse(json['started_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'world_state': worldState,
      'started_at': startedAt.toIso8601String(),
    };
  }
}
