import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/colors.dart';
import '../../data/dnd_reference_data.dart';
import '../../models/ability_scores.dart';
import '../../models/dnd_data.dart';

/// Виджет редактирования характеристик персонажа
class AbilityScoresEditor extends StatelessWidget {
  const AbilityScoresEditor({
    required this.abilityScores, required this.onChanged, super.key,
    this.selectedRace,
    this.highlightedAbilities = const [],
  });

  final AbilityScores abilityScores;
  final void Function(AbilityScores) onChanged;
  final DndRace? selectedRace;
  final List<String> highlightedAbilities;

  @override
  Widget build(BuildContext context) {
    final total = abilityScores.total;
    final isValidTotal = total >= DndReferenceData.minTotalAbilityScore &&
        total <= DndReferenceData.maxTotalAbilityScore;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Информация о сумме
          _TotalIndicator(
            total: total,
            minTotal: DndReferenceData.minTotalAbilityScore,
            maxTotal: DndReferenceData.maxTotalAbilityScore,
            isValid: isValidTotal,
          ),
          const SizedBox(height: 24),

          // Редакторы характеристик
          ...AbilityNames.all.map((ability) {
            final racialBonus = selectedRace?.abilityBonuses[ability] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _AbilityEditor(
                ability: ability,
                value: abilityScores.getValue(ability),
                racialBonus: racialBonus,
                isHighlighted: highlightedAbilities.contains(ability),
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  onChanged(abilityScores.withAbility(ability, value));
                },
              ),
            );
          }),

          const SizedBox(height: 16),

          // Подсказка
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Распределите характеристики от ${DndReferenceData.minAbilityScore} до ${DndReferenceData.maxAbilityScore}. Сумма должна быть от ${DndReferenceData.minTotalAbilityScore} до ${DndReferenceData.maxTotalAbilityScore}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalIndicator extends StatelessWidget {
  const _TotalIndicator({
    required this.total,
    required this.minTotal,
    required this.maxTotal,
    required this.isValid,
  });

  final int total;
  final int minTotal;
  final int maxTotal;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final indicatorColor = isValid ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: indicatorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Сумма характеристик',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$total / $minTotal-$maxTotal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: indicatorColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          Icon(
            isValid ? Icons.check_circle : Icons.warning,
            color: indicatorColor,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _AbilityEditor extends StatelessWidget {
  const _AbilityEditor({
    required this.ability,
    required this.value,
    required this.racialBonus,
    required this.isHighlighted,
    required this.onChanged,
  });

  final String ability;
  final int value;
  final int racialBonus;
  final bool isHighlighted;
  final void Function(int) onChanged;

  int get _modifier => AbilityScores.calculateModifier(value + racialBonus);

  String get _modifierText {
    if (_modifier >= 0) return '+$_modifier';
    return '$_modifier';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = AbilityNames.ruNames[ability] ?? ability;
    final shortName = AbilityNames.shortNames[ability] ?? ability;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.secondary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? AppColors.secondary : AppColors.outline,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Название характеристики
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? AppColors.secondary
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      shortName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isHighlighted
                                ? AppColors.onSecondary
                                : AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurface,
                        ),
                  ),
                ],
              ),

              // Значение и модификатор
              Row(
                children: [
                  // Базовое значение
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  // Расовый бонус
                  if (racialBonus > 0) ...[
                    Text(
                      '+$racialBonus',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  // Модификатор
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _modifier >= 0
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _modifierText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _modifier >= 0
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Слайдер
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isHighlighted
                  ? AppColors.secondary
                  : AppColors.primary,
              inactiveTrackColor: AppColors.surfaceVariant,
              thumbColor: isHighlighted
                  ? AppColors.secondary
                  : AppColors.primary,
              overlayColor: (isHighlighted
                      ? AppColors.secondary
                      : AppColors.primary)
                  .withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: DndReferenceData.minAbilityScore.toDouble(),
              max: DndReferenceData.maxAbilityScore.toDouble(),
              divisions:
                  DndReferenceData.maxAbilityScore - DndReferenceData.minAbilityScore,
              onChanged: (newValue) => onChanged(newValue.round()),
            ),
          ),

          // Кнопки +/-
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AdjustButton(
                icon: Icons.remove,
                onPressed: value > DndReferenceData.minAbilityScore
                    ? () => onChanged(value - 1)
                    : null,
              ),
              const SizedBox(width: 24),
              _AdjustButton(
                icon: Icons.add,
                onPressed: value < DndReferenceData.maxAbilityScore
                    ? () => onChanged(value + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
      color: onPressed != null ? AppColors.surfaceVariant : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onPressed != null ? AppColors.outline : AppColors.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed != null
                ? AppColors.onSurface
                : AppColors.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
}
