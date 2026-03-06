import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/dnd_reference_data.dart';
import '../../models/dnd_data.dart';

/// Виджет выбора класса персонажа
class ClassSelector extends StatelessWidget {
  const ClassSelector({
    required this.onSelect,
    super.key,
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
                    dndClass.iconEmoji ?? '⚔️',
                    style: const TextStyle(fontSize: 28),
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
                        Expanded(
                          child: Text(
                            dndClass.nameRu,
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
                          child: Text(
                            dndClass.hitDie,
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dndClass.descriptionRu,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Основные характеристики
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: dndClass.primaryAbilities
                          .map((ability) => _AbilityChip(ability: ability))
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
          color: const Color(0xFF52B788).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF52B788).withOpacity(0.4),
          ),
        ),
        child: Text(
          _displayName,
          style: const TextStyle(
            color: Color(0xFF52B788),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
