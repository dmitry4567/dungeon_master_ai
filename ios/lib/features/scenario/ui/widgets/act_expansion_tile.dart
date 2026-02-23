import 'package:flutter/material.dart';
import '../../models/scenario_content.dart';

class ActExpansionTile extends StatelessWidget {

  const ActExpansionTile({
    required this.act, super.key,
  });
  final Act act;

  @override
  Widget build(BuildContext context) => Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.movie_filter),
        title: Text(
          act.id,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${act.scenes.length} сцен',
          style: const TextStyle(color: Colors.grey),
        ),
        children: [
          // Entry condition
          _InfoRow(
            icon: Icons.login,
            label: 'Условие входа',
            value: act.entryCondition,
          ),
          const SizedBox(height: 12),

          // Exit conditions
          _InfoRow(
            icon: Icons.logout,
            label: 'Условия выхода',
            value: act.exitConditions.join(', '),
          ),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 8),

          // Scenes
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Сцены:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),

          ...act.scenes.asMap().entries.map((entry) {
            final index = entry.key;
            final scene = entry.value;
            return _SceneCard(
              scene: scene,
              index: index + 1,
            );
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
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
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
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scene.mandatory ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    scene.mandatory ? 'Обязательная' : 'Опциональная',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: scene.mandatory ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Сцена $index: ${scene.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scene.descriptionForAi,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (scene.dmHints.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '💡 Подсказки мастеру:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...scene.dmHints.map((hint) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: Text(
                            hint,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),),
            ],
            if (scene.possibleOutcomes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '🎯 Возможные исходы:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...scene.possibleOutcomes.map((outcome) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: Text(
                            outcome,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),),
            ],
          ],
        ),
      ),
    );
}
