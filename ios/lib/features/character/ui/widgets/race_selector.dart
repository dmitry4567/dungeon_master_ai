import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/colors.dart';
import '../../data/dnd_reference_data.dart';
import '../../models/ability_scores.dart';
import '../../models/dnd_data.dart';

/// Виджет выбора расы персонажа
class RaceSelector extends StatelessWidget {
  const RaceSelector({
    super.key,
    required this.onSelect,
    this.selectedRace,
  });

  final void Function(DndRace) onSelect;
  final DndRace? selectedRace;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: DndReferenceData.races.length,
      itemBuilder: (context, index) {
        final race = DndReferenceData.races[index];
        final isSelected = selectedRace?.id == race.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RaceCard(
            race: race,
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(race);
            },
          ),
        );
      },
    );
  }
}

class _RaceCard extends StatelessWidget {
  const _RaceCard({
    required this.race,
    required this.isSelected,
    required this.onTap,
  });

  final DndRace race;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${race.nameRu}, ${race.descriptionRu}',
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
                      race.iconEmoji ?? '👤',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Информация о расе
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            race.nameRu,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_walk,
                                  size: 12,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${race.speed} фт',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        race.descriptionRu,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurface.withValues(alpha: 0.7),
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Бонусы характеристик
                      Wrap(
                        spacing: 6,
                        children: race.abilityBonuses.entries
                            .map(
                              (e) => _BonusChip(ability: e.key, bonus: e.value),
                            )
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
}

class _BonusChip extends StatelessWidget {
  const _BonusChip({
    required this.ability,
    required this.bonus,
  });

  final String ability;
  final int bonus;

  String get _displayName => AbilityNames.shortNames[ability] ?? ability.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$_displayName +$bonus',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.tertiary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
