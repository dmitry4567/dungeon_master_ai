import 'package:flutter/material.dart';
import '../../../../shared/widgets/themed_icon_button.dart';
import '../../models/room.dart';

/// Аватар игрока в комнате ожидания
class PlayerAvatar extends StatelessWidget {

  const PlayerAvatar({
    required this.player, super.key,
    this.isCurrentUser = false,
    this.onApprove,
    this.onDecline,
  });
  final RoomPlayer player;
  final bool isCurrentUser;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar circle
            CircleAvatar(
              radius: 24,
              backgroundColor: _getStatusColor(player.status).withOpacity(0.2),
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(player.status),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Player info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (player.isHost) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Хост',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '(Вы)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(player.status),
                        size: 14,
                        color: _getStatusColor(player.status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(player.status),
                        style: TextStyle(
                          fontSize: 13,
                          color: _getStatusColor(player.status),
                        ),
                      ),
                      if (player.character != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${player.character!.name} (${player.character!.characterClass})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Action buttons for pending players (host only)
            if (player.status == 'pending' && onApprove != null) ...[
              ThemedIconButton(
                icon: Icons.check_circle_outline,
                onPressed: onApprove,
                tooltip: 'Одобрить',
                iconColor: Colors.green,
                backgroundColor: Colors.green.withOpacity(0.1),
              ),
              ThemedIconButton(
                icon: Icons.cancel_outlined,
                onPressed: onDecline,
                tooltip: 'Отклонить',
                iconColor: Colors.red,
                backgroundColor: Colors.red.withOpacity(0.1),
              ),
            ],
          ],
        ),
      ),
    );

  IconData _getStatusIcon(String status) => switch (status) {
        'pending' => Icons.hourglass_empty,
        'approved' => Icons.check,
        'ready' => Icons.check_circle,
        'declined' => Icons.block,
        _ => Icons.help_outline,
      };

  Color _getStatusColor(String status) => switch (status) {
        'pending' => Colors.orange,
        'approved' => Colors.blue,
        'ready' => Colors.green,
        'declined' => Colors.red,
        _ => Colors.grey,
      };

  String _getStatusText(String status) => switch (status) {
        'pending' => 'Ожидает одобрения',
        'approved' => 'Одобрен',
        'ready' => 'Готов',
        'declined' => 'Отклонён',
        _ => status,
      };
}
