import 'package:freezed_annotation/freezed_annotation.dart';
import '../../character/models/character.dart';
import '../../scenario/models/scenario.dart';

part 'room.freezed.dart';
part 'room.g.dart';

/// Room player in a game room
@freezed
class RoomPlayer with _$RoomPlayer {
  const factory RoomPlayer({
    required String id,
    required String userId,
    required String name,
    required String status,
    required bool isHost,
    Character? character,
  }) = _RoomPlayer;

  factory RoomPlayer.fromJson(Map<String, dynamic> json) =>
      _$RoomPlayerFromJson(json);
}

/// Full room detail response
@freezed
class Room with _$Room {
  const factory Room({
    required String id,
    required String name,
    required String status,
    required int maxPlayers,
    required DateTime createdAt,
    Scenario? scenario,
    @Default([]) List<RoomPlayer> players,
  }) = _Room;
  const Room._();

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);

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
@freezed
class RoomSummary with _$RoomSummary {
  const factory RoomSummary({
    required String id,
    required String name,
    required String scenarioTitle,
    required String hostName,
    required int playerCount,
    required int maxPlayers,
    required String status,
    @Default(false) bool isCurrentUserPlayer,
  }) = _RoomSummary;

  factory RoomSummary.fromJson(Map<String, dynamic> json) =>
      _$RoomSummaryFromJson(json);
}

/// Request to create a new room
@freezed
class CreateRoomRequest with _$CreateRoomRequest {
  const factory CreateRoomRequest({
    required String name,
    required String scenarioVersionId,
    @Default(5) int maxPlayers,
  }) = _CreateRoomRequest;

  factory CreateRoomRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateRoomRequestFromJson(json);
}

/// Request to toggle ready status
@freezed
class ReadyRequest with _$ReadyRequest {
  const factory ReadyRequest({
    required bool ready, String? characterId,
  }) = _ReadyRequest;

  factory ReadyRequest.fromJson(Map<String, dynamic> json) =>
      _$ReadyRequestFromJson(json);
}

/// Game session response from start endpoint
@freezed
class GameSessionResponse with _$GameSessionResponse {
  const factory GameSessionResponse({
    required String id,
    required String roomId,
    required Map<String, dynamic> worldState,
    required DateTime startedAt,
  }) = _GameSessionResponse;

  factory GameSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$GameSessionResponseFromJson(json);
}
