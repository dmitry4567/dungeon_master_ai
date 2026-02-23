import 'package:ai_dungeon_master/features/character/models/ability_scores.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/colors.dart';
import '../../data/dnd_reference_data.dart';
import '../../models/character.dart';

/// Карточка персонажа для отображения в списке
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    required this.character, required this.onTap, super.key,
    this.onLongPress,
  });

  final Character character;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final dndClass = DndReferenceData.findClassById(character.characterClass);
    final dndRace = DndReferenceData.findRaceById(character.race);

    return Semantics(
      button: true,
      label:
          '${character.name}, ${dndRace?.nameRu ?? character.race} ${dndClass?.nameRu ?? character.characterClass}, уровень ${character.level}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                // Аватар/иконка класса
                _CharacterAvatar(
                  emoji: dndClass?.iconEmoji ?? '⚔️',
                  level: character.level,
                ),
                const SizedBox(width: 16),

                // Информация о персонаже
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Имя
                      Text(
                        character.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Раса и класс
                      Text(
                        '${dndRace?.nameRu ?? character.race} ${dndClass?.nameRu ?? character.characterClass}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Характеристики preview
                      _AbilityScoresPreview(
                        scores: character.abilityScores,
                      ),
                    ],
                  ),
                ),

                // Стрелка
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar({
    required this.emoji,
    required this.level,
  });

  final String emoji;
  final int level;

  @override
  Widget build(BuildContext context) => Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.3),
                AppColors.primary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        // Бейдж уровня
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: Text(
              '$level',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSecondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
      ],
    );
}

class _AbilityScoresPreview extends StatelessWidget {
  const _AbilityScoresPreview({required this.scores});

  final AbilityScores scores; // AbilityScores

  @override
  Widget build(BuildContext context) {
    final abilities = [
      ('СИЛ', scores.strength),
      ('ЛОВ', scores.dexterity),
      ('ТЕЛ', scores.constitution),
      ('ИНТ', scores.intelligence),
      ('МДР', scores.wisdom),
      ('ХАР', scores.charisma),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: abilities
          .map((a) => _MiniAbilityChip(name: a.$1, value: a.$2))
          .toList(),
    );
  }
}

class _MiniAbilityChip extends StatelessWidget {
  const _MiniAbilityChip({
    required this.name,
    required this.value,
  });

  final String name;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$name $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
      ),
    );
}
