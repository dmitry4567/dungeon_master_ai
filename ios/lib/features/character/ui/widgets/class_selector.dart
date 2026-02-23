import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/colors.dart';
import '../../data/dnd_reference_data.dart';
import '../../models/dnd_data.dart';

/// Виджет выбора класса персонажа
class ClassSelector extends StatelessWidget {
  const ClassSelector({
    required this.onSelect, super.key,
    this.selectedClass,
  });

  final void Function(DndClass) onSelect;
  final DndClass? selectedClass;

  @override
  Widget build(BuildContext context) => ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: DndReferenceData.classes.length,
      itemBuilder: (context, index) {
        final dndClass = DndReferenceData.classes[index];
        final isSelected = selectedClass?.id == dndClass.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ClassCard(
            dndClass: dndClass,
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(dndClass);
            },
          ),
        );
      },
    );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.dndClass,
    required this.isSelected,
    required this.onTap,
  });

  final DndClass dndClass;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: isSelected,
      label: '${dndClass.nameRu}, ${dndClass.descriptionRu}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Иконка/эмодзи
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      dndClass.iconEmoji ?? '⚔️',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Информация о классе
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dndClass.nameRu,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              dndClass.hitDie,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dndClass.descriptionRu,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurface.withValues(alpha: 0.7),
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Основные характеристики
                      Wrap(
                        spacing: 6,
                        children: dndClass.primaryAbilities
                            .map((ability) => _AbilityChip(ability: ability))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                // Индикатор выбора
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
}

class _AbilityChip extends StatelessWidget {
  const _AbilityChip({required this.ability});

  final String ability;

  String get _displayName => switch (ability) {
      'strength' => 'СИЛ',
      'dexterity' => 'ЛОВ',
      'constitution' => 'ТЕЛ',
      'intelligence' => 'ИНТ',
      'wisdom' => 'МДР',
      'charisma' => 'ХАР',
      _ => ability.toUpperCase(),
    };

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
}
