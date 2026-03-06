import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/scenario.dart';

class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    required this.scenario,
    required this.onTap,
    super.key,
  });

  final Scenario scenario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = scenario.currentVersion?.content;
    final status = _StatusInfo.from(scenario.status);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    color: Color(0xFFD4AF37),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scenario.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: status.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: status.color.withOpacity(0.35)),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF3A3A5E)),
              ],
            ),
            if (content != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 0.5,
                color: const Color(0xFF2A2A4E),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _InfoChip(icon: Icons.trending_up_outlined, label: content.difficulty),
                  _InfoChip(icon: Icons.palette_outlined, label: content.tone),
                  _InfoChip(
                    icon: Icons.group_outlined,
                    label: '${content.playersMin}–${content.playersMax} игр.',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatItem(icon: Icons.theater_comedy_outlined, count: content.acts.length, label: 'Актов'),
                  const SizedBox(width: 16),
                  _StatItem(icon: Icons.person_outline, count: content.npcs.length, label: 'NPC'),
                  const SizedBox(width: 16),
                  _StatItem(icon: Icons.location_on_outlined, count: content.locations.length, label: 'Локаций'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusInfo {
  const _StatusInfo({required this.label, required this.color});

  factory _StatusInfo.from(String status) => switch (status) {
        'draft' => const _StatusInfo(label: 'Черновик', color: Color(0xFFF4A261)),
        'published' => const _StatusInfo(label: 'Опубликован', color: Color(0xFF52B788)),
        'archived' => const _StatusInfo(label: 'Архив', color: Color(0xFF6B7280)),
        _ => const _StatusInfo(label: 'Неизвестно', color: Color(0xFF6B7280)),
      };

  final String label;
  final Color color;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFFD4AF37)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.count, required this.label});

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5A5A7E)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      );
}
