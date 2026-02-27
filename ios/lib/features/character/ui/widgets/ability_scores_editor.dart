import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/dnd_reference_data.dart';
import '../../models/ability_scores.dart';
import '../../models/dnd_data.dart';

/// Виджет редактирования характеристик персонажа
class AbilityScoresEditor extends StatelessWidget {
  const AbilityScoresEditor({
    required this.abilityScores,
    required this.onChanged,
    super.key,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A4E)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Распределите характеристики от ${DndReferenceData.minAbilityScore} до ${DndReferenceData.maxAbilityScore}. Сумма должна быть от ${DndReferenceData.minTotalAbilityScore} до ${DndReferenceData.maxTotalAbilityScore}.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (isValid ? const Color(0xFF52B788) : const Color(0xFFE76F51))
                  .withOpacity(0.1),
              (isValid ? const Color(0xFF52B788) : const Color(0xFFE76F51))
                  .withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isValid ? const Color(0xFF52B788) : const Color(0xFFE76F51))
                .withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Сумма характеристик',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total / $minTotal-$maxTotal',
                  style: TextStyle(
                    color: isValid
                        ? const Color(0xFF52B788)
                        : const Color(0xFFE76F51),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isValid
                        ? const Color(0xFF52B788)
                        : const Color(0xFFE76F51))
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isValid ? Icons.check_circle : Icons.warning,
                color:
                    isValid ? const Color(0xFF52B788) : const Color(0xFFE76F51),
                size: 24,
              ),
            ),
          ],
        ),
      );
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
            ? const Color(0xFF52B788).withOpacity(0.1)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isHighlighted ? const Color(0xFF52B788) : const Color(0xFF2A2A4E),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? const Color(0xFF52B788)
                      : const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayName.toUpperCase(),
                  style: TextStyle(
                    color:
                        isHighlighted ? const Color(0xFF0D0D1A) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Значение и модификатор
              Row(
                children: [
                  // Базовое значение
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Расовый бонус
                  if (racialBonus > 0) ...[
                    Text(
                      '+$racialBonus',
                      style: const TextStyle(
                        color: Color(0xFFF4A261),
                        fontSize: 16,
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
                          ? const Color(0xFF52B788).withOpacity(0.2)
                          : const Color(0xFFE76F51).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _modifier >= 0
                            ? const Color(0xFF52B788).withOpacity(0.4)
                            : const Color(0xFFE76F51).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      _modifierText,
                      style: TextStyle(
                        color: _modifier >= 0
                            ? const Color(0xFF52B788)
                            : const Color(0xFFE76F51),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Слайдер
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isHighlighted
                  ? const Color(0xFF52B788)
                  : const Color(0xFFD4AF37),
              inactiveTrackColor: const Color(0xFF2A2A4E),
              thumbColor: isHighlighted
                  ? const Color(0xFF52B788)
                  : const Color(0xFFD4AF37),
              overlayColor: (isHighlighted
                      ? const Color(0xFF52B788)
                      : const Color(0xFFD4AF37))
                  .withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(),
            ),
            child: Slider(
              value: value.toDouble(),
              min: DndReferenceData.minAbilityScore.toDouble(),
              max: DndReferenceData.maxAbilityScore.toDouble(),
              divisions: DndReferenceData.maxAbilityScore -
                  DndReferenceData.minAbilityScore,
              onChanged: (newValue) => onChanged(newValue.round()),
            ),
          ),

          // Кнопки +/-
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AdjustButton(
                icon: Icons.remove,
                onPressed: value > DndReferenceData.minAbilityScore
                    ? () => onChanged(value - 1)
                    : null,
              ),
              // const SizedBox(width: 50),
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
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 100,
          height: 46,
          decoration: BoxDecoration(
            color: onPressed != null
                ? const Color(0xFF2A2A4A)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onPressed != null
                  ? const Color(0xFF3A3A5E)
                  : const Color(0xFF2A2A4E),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed != null
                ? const Color(0xFFD4AF37)
                : const Color(0xFF3A3A5E),
            size: 20,
          ),
        ),
      );
}
