import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/game_history.dart';

/// Карточка истории игры
class GameHistoryCard extends StatelessWidget {
  const GameHistoryCard({
    required this.game, super.key,
  });

  final GameHistory game;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('HH:mm');
    final isCompleted = game.endedAt != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Navigate to game details
        },
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF2A4A2E)
                  : const Color(0xFF4A3A1A),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF1E3A22)
                        : const Color(0xFF3A2E0A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.castle_outlined,
                    color: isCompleted
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFFD4AF37),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              game.scenarioTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(isCompleted: isCompleted),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        game.roomName,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: dateFormat.format(game.startedAt),
                          ),
                          const SizedBox(width: 10),
                          _MetaChip(
                            icon: Icons.access_time_outlined,
                            label: timeFormat.format(game.startedAt),
                          ),
                          if (game.playerNames.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            _MetaChip(
                              icon: Icons.people_outline,
                              label: '${game.playerNames.length}',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF1E3A22)
            : const Color(0xFF3A2E0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF66BB6A).withOpacity(0.4)
              : const Color(0xFFD4AF37).withOpacity(0.4),
        ),
      ),
      child: Text(
        isCompleted ? 'Завершена' : 'Активна',
        style: TextStyle(
          color: isCompleted ? const Color(0xFF66BB6A) : const Color(0xFFD4AF37),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white30),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
}
