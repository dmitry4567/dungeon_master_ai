import 'package:freezed_annotation/freezed_annotation.dart';

import 'dice_result.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Роль автора сообщения
enum MessageRole {
  @JsonValue('player')
  player,
  @JsonValue('dm')
  dm,
  @JsonValue('system')
  system,
}

/// Сообщение в игровой сессии
@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    @JsonKey(name: 'author_id') String? authorId,
    @JsonKey(name: 'author_name') String? authorName,
    required MessageRole role,
    required String content,
    @JsonKey(name: 'dice_result') DiceResult? diceResult,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'state_delta') Map<String, dynamic>? stateDelta,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
