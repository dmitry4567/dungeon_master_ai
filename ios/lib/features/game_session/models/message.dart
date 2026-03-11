import 'dice_result.dart';

/// Роль автора сообщения
enum MessageRole {
  player,
  dm,
  system,
}

/// Сообщение в игровой сессии
class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final String? authorId;
  final String? authorName;
  final DiceResult? diceResult;
  final Map<String, dynamic>? stateDelta;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.diceResult,
    this.stateDelta,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.name == (json['role'] as String),
        orElse: () => MessageRole.system,
      ),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorId: json['author_id'] as String?,
      authorName: json['author_name'] as String?,
      diceResult: json['dice_result'] != null
          ? DiceResult.fromJson(json['dice_result'] as Map<String, dynamic>)
          : null,
      stateDelta: json['state_delta'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      if (authorId != null) 'author_id': authorId,
      if (authorName != null) 'author_name': authorName,
      if (diceResult != null) 'dice_result': diceResult!.toJson(),
      if (stateDelta != null) 'state_delta': stateDelta,
    };
  }
}
