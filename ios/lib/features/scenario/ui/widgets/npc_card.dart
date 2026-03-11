import 'package:flutter/material.dart';
import '../../models/scenario_content.dart';

class NpcCard extends StatelessWidget {
  const NpcCard({
    required this.npc,
    super.key,
  });

  final Npc npc;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.all(16),
          leading: _getRoleIcon(npc.role),
          title: Text(
            npc.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            _getRoleText(npc.role),
            style: TextStyle(
              color: _getRoleColor(npc.role),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          shape: const Border(),
          collapsedShape: const Border(),
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
              const Divider(color: Color(0xFF2A2A4E)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE76F51).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '🔒',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Секреты (${npc.secrets.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...npc.secrets.map((secret) => Padding(
                    padding: const EdgeInsets.only(left: 34, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: Color(0xFFE76F51)),
                        ),
                        Expanded(
                          child: Text(
                            secret,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
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
        color = const Color(0xFF52B788);
      case 'enemy':
        icon = Icons.warning;
        color = const Color(0xFFE76F51);
      case 'neutral':
        icon = Icons.remove_circle_outline;
        color = const Color(0xFF6B7280);
      case 'quest_giver':
        icon = Icons.emoji_events;
        color = const Color(0xFFF4A261);
      case 'antagonist':
        icon = Icons.dangerous;
        color = const Color(0xFFE76F51);
      default:
        icon = Icons.person;
        color = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
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
        return const Color(0xFF52B788);
      case 'enemy':
        return const Color(0xFFE76F51);
      case 'neutral':
        return const Color(0xFF6B7280);
      case 'quest_giver':
        return const Color(0xFFF4A261);
      case 'antagonist':
        return const Color(0xFFE76F51);
      default:
        return const Color(0xFF6B7280);
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
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon, size: 14, color: const Color(0xFFD4AF37)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 27),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}
