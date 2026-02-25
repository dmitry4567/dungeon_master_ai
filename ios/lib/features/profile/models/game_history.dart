import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_history.freezed.dart';
part 'game_history.g.dart';

/// История игры
@freezed
class GameHistory with _$GameHistory {
  const factory GameHistory({
    required String id,
    required String roomName,
    required String scenarioTitle,
    required DateTime startedAt,
    required List<String> playerNames,
    required int messageCount,
    DateTime? endedAt,
  }) = _GameHistory;

  factory GameHistory.fromJson(Map<String, dynamic> json) =>
      _$GameHistoryFromJson(json);
}
