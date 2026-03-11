import 'package:flutter/material.dart';
import '../../models/scenario_content.dart';

class ActExpansionTile extends StatelessWidget {
  const ActExpansionTile({
    required this.act,
    super.key,
  });

  final Act act;

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
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.movie_filter,
              color: Color(0xFFD4AF37),
              size: 18,
            ),
          ),
          title: Text(
            act.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '${act.scenes.length} сцен',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            // Entry condition
            _InfoRow(
              icon: Icons.login,
              label: 'Условие входа',
              value: act.entryCondition.description,
            ),
            const SizedBox(height: 12),

            // Exit conditions
            _InfoRow(
              icon: Icons.logout,
              label: 'Условия выхода',
              value: act.exitConditions.map((c) => c.description).join(', '),
            ),
            const SizedBox(height: 16),

            const Divider(color: Color(0xFF2A2A4E)),
            const SizedBox(height: 8),

            // Scenes
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Сцены:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ...act.scenes.asMap().entries.map((entry) {
              final index = entry.key;
              final scene = entry.value;
              return _SceneCard(scene: scene, index: index + 1);
            }),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFD4AF37)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.scene,
    required this.index,
  });

  final Scene scene;
  final int index;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scene.mandatory
                        ? const Color(0xFFE76F51).withOpacity(0.2)
                        : const Color(0xFF2A9D8F).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: scene.mandatory
                          ? const Color(0xFFE76F51).withOpacity(0.4)
                          : const Color(0xFF2A9D8F).withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    scene.mandatory ? 'Обязательная' : 'Опциональная',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: scene.mandatory
                          ? const Color(0xFFE76F51)
                          : const Color(0xFF2A9D8F),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Сцена $index: ${scene.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              scene.descriptionForAi,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            if (scene.dmHints.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '💡',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Подсказки мастеру:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...scene.dmHints.map((hint) => Padding(
                    padding: const EdgeInsets.only(left: 26, top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: Color(0xFFD4AF37)),
                        ),
                        Expanded(
                          child: Text(
                            hint,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),),
            ],
            if (scene.possibleOutcomes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A9D8F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '🎯',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Возможные исходы:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...scene.possibleOutcomes.map((outcome) => Padding(
                    padding: const EdgeInsets.only(left: 26, top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: Color(0xFF2A9D8F)),
                        ),
                        Expanded(
                          child: Text(
                            outcome,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
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
}
