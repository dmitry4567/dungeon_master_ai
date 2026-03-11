/// История игры
class GameHistory {
  final String id;
  final String roomName;
  final String scenarioTitle;
  final DateTime startedAt;
  final List<String> playerNames;
  final int messageCount;
  final DateTime? endedAt;

  const GameHistory({
    required this.id,
    required this.roomName,
    required this.scenarioTitle,
    required this.startedAt,
    required this.playerNames,
    required this.messageCount,
    this.endedAt,
  });

  factory GameHistory.fromJson(Map<String, dynamic> json) {
    return GameHistory(
      id: json['id'] as String,
      roomName: json['room_name'] as String,
      scenarioTitle: json['scenario_title'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      playerNames: (json['player_names'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      messageCount: (json['message_count'] as num).toInt(),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_name': roomName,
      'scenario_title': scenarioTitle,
      'started_at': startedAt.toIso8601String(),
      'player_names': playerNames,
      'message_count': messageCount,
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
    };
  }
}
