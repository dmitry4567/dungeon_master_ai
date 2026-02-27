import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../scenario/models/scenario_content.dart';
import '../../models/world_state.dart';

/// Панель состояния мира
class WorldStateBar extends StatefulWidget {
  const WorldStateBar({
    required this.worldState,
    required this.scenarioContent,
    super.key,
  });

  final WorldState worldState;
  final ScenarioContent scenarioContent;

  @override
  State<WorldStateBar> createState() => _WorldStateBarState();
}

class _WorldStateBarState extends State<WorldStateBar> {
  bool _expanded = false;

  String _getFlagLabel(String flagId, dynamic flagData) {
    // Сначала ищем в predefined flags сценария
    for (final flag in widget.scenarioContent.flags) {
      if (flag.id == flagId) {
        return flag.name;
      }
    }
    // Новый формат: {"value": bool, "label": "Human readable"}
    if (flagData is Map && flagData['label'] != null) {
      return flagData['label'] as String;
    }
    // Fallback: ID (не должно случаться с новым форматом)
    return flagId;
  }

  bool _getFlagValue(dynamic flagData) {
    if (flagData is Map) return flagData['value'] as bool? ?? false;
    if (flagData is bool) return flagData;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Act? currentAct;
    for (final act in widget.scenarioContent.acts) {
      if (act.id == widget.worldState.currentAct) {
        currentAct = act;
        break;
      }
    }
    final actName = currentAct?.name ?? widget.worldState.currentAct;

    Location? currentLocation;
    if (widget.worldState.currentLocation != null) {
      for (final loc in widget.scenarioContent.locations) {
        if (loc.id == widget.worldState.currentLocation!) {
          currentLocation = loc;
          break;
        }
      }
    }
    final locationName =
        currentLocation?.name ?? widget.worldState.currentLocation;

    final completedSceneNames =
        widget.worldState.completedScenes.map((sceneId) {
      for (final act in widget.scenarioContent.acts) {
        for (final scene in act.scenes) {
          if (scene.id == sceneId) {
            return scene.name;
          }
        }
      }
      return sceneId; // Fallback to ID if not found
    }).toList();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          border: Border(
            bottom: BorderSide(
              color: widget.worldState.combatActive
                  ? AppColors.error
                  : const Color(0xFF2A2A4E),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Основная строка
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Контент слева (все чипы с ограничением по ширине)
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Индикатор боя
                        if (widget.worldState.combatActive)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flash_on,
                                  color: AppColors.error,
                                  size: 12,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'БОЙ',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Акт
                        _InfoChip(
                          icon: Icons.menu_book,
                          label: actName,
                        ),
                        if (widget.worldState.currentScene != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.theaters,
                            label: widget.worldState.currentScene!,
                          ),
                        ],
                        if (locationName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: _InfoChip(
                              icon: Icons.location_on,
                              label: locationName,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Иконка справа (фиксированная)
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.onSurface.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
            // Раскрывающаяся секция
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Color(0xFF2A2A4E), height: 1),
                    const SizedBox(height: 8),
                    // Пройденные сцены
                    if (completedSceneNames.isNotEmpty) ...[
                      Text(
                        'Пройденные сцены:',
                        style: TextStyle(
                          color: AppColors.onSurface.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: completedSceneNames
                            .map((name) => _MiniChip(label: name))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Флаги
                    if (widget.worldState.flags.isNotEmpty) ...[
                      const Text(
                        'Флаги мира:',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: widget.worldState.flags.entries
                            .map(
                              (e) => _MiniChip(
                                label: _getFlagLabel(e.key, e.value),
                                active: _getFlagValue(e.value),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (completedSceneNames.isEmpty &&
                        widget.worldState.flags.isEmpty)
                      Text(
                        'Нет дополнительной информации',
                        style: TextStyle(
                          color: AppColors.onSurface.withValues(alpha: 0.4),
                          fontSize: 12,
                          // fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF2A2A4E), size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, this.active = true});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? AppColors.tertiary.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.tertiary.withValues(alpha: 0.4)
                : AppColors.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? AppColors.tertiaryLight
                : AppColors.onSurface.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      );
}
