import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/dnd_reference_data.dart';
import '../../models/character.dart';
import '../../models/ability_scores.dart';

/// Карточка персонажа для отображения в списке
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    required this.character,
    required this.onTap,
    super.key,
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A4E)),
          ),
          child: Row(
            children: [
              _CharacterAvatar(
                emoji: dndClass?.iconEmoji ?? '⚔️',
                level: character.level,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dndRace?.nameRu ?? character.race} · ${dndClass?.nameRu ?? character.characterClass}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AbilityScoresPreview(scores: character.abilityScores),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF3A3A5E),
              ),
            ],
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
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2A4A),
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF1A1A2E),
                  width: 2,
                ),
              ),
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
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

  final AbilityScores scores;

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
      spacing: 6,
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Text(
          '$name $value',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
