import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/dnd_reference_data.dart';
import '../../models/ability_scores.dart';
import '../../models/dnd_data.dart';

/// Виджет выбора расы персонажа
class RaceSelector extends StatelessWidget {
  const RaceSelector({
    required this.onSelect,
    super.key,
    this.selectedRace,
  });

  final void Function(DndRace) onSelect;
  final DndRace? selectedRace;

  @override
  Widget build(BuildContext context) => ListView.builder(
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD4AF37).withOpacity(0.1)
                : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFF2A2A4E),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Иконка/эмодзи
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFD4AF37).withOpacity(0.2)
                      : const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFF3A3A5E),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    race.iconEmoji ?? '👤',
                    style: const TextStyle(fontSize: 28),
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
                        Expanded(
                          child: Text(
                            race.nameRu,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.directions_walk,
                                size: 12,
                                color: Color(0xFFD4AF37),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${race.speed} фт',
                                style: const TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Бонусы характеристик
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFFD4AF37),
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF4A261).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFF4A261).withOpacity(0.4),
          ),
        ),
        child: Text(
          '$_displayName +$bonus',
          style: const TextStyle(
            color: Color(0xFFF4A261),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
