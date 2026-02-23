import 'package:flutter/material.dart';
import '../../models/scenario_content.dart';

class NpcCard extends StatelessWidget {

  const NpcCard({
    required this.npc, super.key,
  });
  final Npc npc;

  @override
  Widget build(BuildContext context) => Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.all(16),
        leading: _getRoleIcon(npc.role),
        title: Text(
          npc.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _getRoleText(npc.role),
          style: TextStyle(
            color: _getRoleColor(npc.role),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        children: [
          // Personality
          _InfoSection(
            icon: Icons.psychology,
            title: 'Личность',
            content: npc.personality,
          ),
          const SizedBox(height: 12),

          // Speech style
          _InfoSection(
            icon: Icons.chat_bubble_outline,
            title: 'Стиль речи',
            content: npc.speechStyle,
          ),
          const SizedBox(height: 12),

          // Motivation
          _InfoSection(
            icon: Icons.flag,
            title: 'Мотивация',
            content: npc.motivation,
          ),
          const SizedBox(height: 12),

          // Secrets
          if (npc.secrets.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lock, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Секреты (${npc.secrets.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...npc.secrets.map((secret) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔒 ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          secret,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),),
          ],
        ],
      ),
    );

  Widget _getRoleIcon(String role) {
    IconData icon;
    Color color;

    switch (role.toLowerCase()) {
      case 'ally':
        icon = Icons.favorite;
        color = Colors.green;
      case 'enemy':
        icon = Icons.warning;
        color = Colors.red;
      case 'neutral':
        icon = Icons.remove_circle_outline;
        color = Colors.grey;
      case 'quest_giver':
        icon = Icons.emoji_events;
        color = Colors.amber;
      case 'antagonist':
        icon = Icons.dangerous;
        color = Colors.deepOrange;
      default:
        icon = Icons.person;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'ally':
        return 'Союзник';
      case 'enemy':
        return 'Враг';
      case 'neutral':
        return 'Нейтрал';
      case 'quest_giver':
        return 'Квестодатель';
      case 'antagonist':
        return 'Антагонист';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'ally':
        return Colors.green;
      case 'enemy':
        return Colors.red;
      case 'neutral':
        return Colors.grey;
      case 'quest_giver':
        return Colors.amber;
      case 'antagonist':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}

class _InfoSection extends StatelessWidget {

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.content,
  });
  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
}
