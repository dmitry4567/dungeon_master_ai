import 'package:freezed_annotation/freezed_annotation.dart';

part 'world_state.freezed.dart';
part 'world_state.g.dart';

/// Состояние игрового мира
@freezed
class WorldState with _$WorldState {
  const factory WorldState({
    @JsonKey(name: 'current_act') @Default('act_1') String currentAct,
    @JsonKey(name: 'current_scene') String? currentScene,
    @JsonKey(name: 'current_location') String? currentLocation,
    @JsonKey(name: 'completed_scenes')
    @Default([])
    List<String> completedScenes,
    @Default({}) Map<String, bool> flags,
    @JsonKey(name: 'combat_active') @Default(false) bool combatActive,
  }) = _WorldState;

  factory WorldState.fromJson(Map<String, dynamic> json) =>
      _$WorldStateFromJson(json);
}

/// Игровая сессия
@freezed
class GameSession with _$GameSession {
  const factory GameSession({
    required String id,
    @JsonKey(name: 'room_id') required String roomId,
    @JsonKey(name: 'world_state') required WorldState worldState,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'ended_at') DateTime? endedAt,
  }) = _GameSession;

  factory GameSession.fromJson(Map<String, dynamic> json) =>
      _$GameSessionFromJson(json);
}

/// Статус сессии
@freezed
class SessionStatus with _$SessionStatus {
  const factory SessionStatus({
    @JsonKey(name: 'session_id') required String sessionId,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'current_act') String? currentAct,
    @JsonKey(name: 'current_scene') String? currentScene,
    @JsonKey(name: 'current_location') String? currentLocation,
    @JsonKey(name: 'combat_active') @Default(false) bool combatActive,
    @JsonKey(name: 'player_count') @Default(0) int playerCount,
    @JsonKey(name: 'message_count') @Default(0) int messageCount,
  }) = _SessionStatus;

  factory SessionStatus.fromJson(Map<String, dynamic> json) =>
      _$SessionStatusFromJson(json);
}
