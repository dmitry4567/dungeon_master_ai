import 'package:flutter/material.dart';
import '../../models/room.dart';

/// Карточка комнаты в списке лобби
class RoomCard extends StatelessWidget {
  const RoomCard({
    required this.room,
    required this.onTap,
    super.key,
  });

  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A4E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2A2A4A),
                      border: Border.all(
                        color: _getStatusColor(room.status),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _getStatusIcon(room.status),
                      color: _getStatusColor(room.status),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_stories,
                              size: 14,
                              color: Color(0xFFD4AF37),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                room.scenarioTitle,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF3A3A5E),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2A2A4E),
                      const Color(0xFF2A2A4E).withOpacity(0.3),
                      const Color(0xFF2A2A4E),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.person_outline,
                    label: room.hostName,
                    isHost: true,
                  ),
                  const Spacer(),
                  _InfoChip(
                    icon: Icons.people_outline,
                    label: '${room.playerCount}/${room.maxPlayers}',
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: room.status),
                ],
              ),
            ],
          ),
        ),
      );

  IconData _getStatusIcon(String status) => switch (status) {
        'waiting' => Icons.hourglass_empty,
        'active' => Icons.play_circle_filled,
        'completed' => Icons.check_circle,
        _ => Icons.help_outline,
      };

  Color _getStatusColor(String status) => switch (status) {
        'waiting' => const Color(0xFFF4A261),
        'active' => const Color(0xFF52B788),
        'completed' => const Color(0xFF6B7280),
        _ => const Color(0xFF6B7280),
      };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.isHost = false,
  });

  final IconData icon;
  final String label;
  final bool isHost;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isHost
                  ? const Color(0xFFD4AF37).withOpacity(0.1)
                  : const Color(0xFF2A2A4A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isHost ? const Color(0xFFD4AF37) : const Color(0xFF5A5A7E),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isHost ? const Color(0xFFD4AF37) : const Color(0xFF5A5A7E),
              fontWeight: isHost ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) => switch (status) {
        'waiting' => const Color(0xFFF4A261),
        'active' => const Color(0xFF52B788),
        'completed' => const Color(0xFF6B7280),
        _ => const Color(0xFF6B7280),
      };

  String _getStatusText(String status) => switch (status) {
        'waiting' => 'Ожидание',
        'active' => 'В игре',
        'completed' => 'Завершена',
        _ => status,
      };
}
