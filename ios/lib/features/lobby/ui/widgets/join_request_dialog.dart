import 'package:flutter/material.dart';
import '../../models/room.dart';

/// Диалог подтверждения запроса на вступление
class JoinRequestDialog extends StatelessWidget {

  const JoinRequestDialog({
    required this.player, required this.onApprove, required this.onDecline, super.key,
  });
  final RoomPlayer player;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  /// Показать диалог
  static Future<bool?> show(
    BuildContext context, {
    required RoomPlayer player,
    required VoidCallback onApprove,
    required VoidCallback onDecline,
  }) => showDialog<bool>(
      context: context,
      builder: (context) => JoinRequestDialog(
        player: player,
        onApprove: () {
          onApprove();
          Navigator.of(context).pop(true);
        },
        onDecline: () {
          onDecline();
          Navigator.of(context).pop(false);
        },
      ),
    );

  @override
  Widget build(BuildContext context) => AlertDialog(
      title: const Text('Запрос на вступление'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
            child: Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            player.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'хочет присоединиться к комнате',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDecline,
          child: const Text(
            'Отклонить',
            style: TextStyle(color: Colors.red),
          ),
        ),
        ElevatedButton(
          onPressed: onApprove,
          child: const Text('Одобрить'),
        ),
      ],
    );
}
