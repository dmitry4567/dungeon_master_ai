import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/fantasy_button.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../bloc/character_bloc.dart';
import '../bloc/character_event.dart';
import '../bloc/character_state.dart';
import '../data/dnd_reference_data.dart';
import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/dnd_data.dart';

/// Страница деталей персонажа
class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({
    required this.characterId, super.key,
  });

  final String characterId;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage> {
  @override
  void initState() {
    super.initState();
    // Загрузить персонажа
    context.read<CharacterBloc>().add(
          CharacterEvent.loadCharacter(id: widget.characterId),
        );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<CharacterBloc, CharacterState>(
      listener: (context, state) {
        if (state is CharacterDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Персонаж удалён'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(Routes.characters);
        } else if (state is CharacterError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) => switch (state) {
          CharacterLoading() => const _LoadingView(),
          CharacterDetail(:final character) =>
            _CharacterDetailView(character: character),
          CharacterError(:final message) => Scaffold(
              appBar: AppBar(title: const Text('Персонаж')),
              body: ErrorView(
                message: message,
                onRetry: () {
                  context.read<CharacterBloc>().add(
                        CharacterEvent.loadCharacter(id: widget.characterId),
                      );
                },
              ),
            ),
          _ => const _LoadingView(),
        },
    );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Персонаж')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LoadingSkeleton(height: 120, borderRadius: 12),
            SizedBox(height: 24),
            LoadingSkeleton(height: 200, borderRadius: 12),
            SizedBox(height: 24),
            LoadingSkeleton(height: 100, borderRadius: 12),
          ],
        ),
      ),
    );
}

class _CharacterDetailView extends StatelessWidget {
  const _CharacterDetailView({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final dndClass = DndReferenceData.findClassById(character.characterClass);
    final dndRace = DndReferenceData.findRaceById(character.race);

    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Удалить', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Карточка с основной информацией
            _HeaderCard(
              character: character,
              dndClass: dndClass,
              dndRace: dndRace,
            ),
            const SizedBox(height: 24),

            // Характеристики
            _AbilityScoresCard(abilityScores: character.abilityScores),
            const SizedBox(height: 24),

            // Предыстория
            if (character.backstory != null &&
                character.backstory!.isNotEmpty) ...[
              _BackstoryCard(backstory: character.backstory!),
              const SizedBox(height: 24),
            ],

            // Дополнительная информация
            _InfoCard(character: character, dndClass: dndClass),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FantasyButton(
            label: 'Играть',
            icon: Icons.play_arrow,
            onPressed: () {
              // Переход к лобби для создания комнаты
              context.go(Routes.lobby);
            },
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить персонажа?'),
        content: Text(
          'Персонаж "${character.name}" будет удалён безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CharacterBloc>().add(
                    CharacterEvent.deleteCharacter(id: character.id),
                  );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.character,
    this.dndClass,
    this.dndRace,
  });

  final Character character;
  final DndClass? dndClass;
  final dynamic dndRace;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Аватар
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                dndClass?.iconEmoji ?? '⚔️',
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dndRace?.nameRu ?? character.race} ${dndClass?.nameRu ?? character.characterClass}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.8),
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatBadge(
                      icon: Icons.star,
                      label: 'Уровень',
                      value: '${character.level}',
                    ),
                    const SizedBox(width: 16),
                    _StatBadge(
                      icon: Icons.favorite,
                      label: 'HP',
                      value: '${character.maxHitPoints}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.7),
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
}

class _AbilityScoresCard extends StatelessWidget {
  const _AbilityScoresCard({required this.abilityScores});

  final AbilityScores abilityScores;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Характеристики',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AbilityScoreItem(
                  name: 'СИЛ',
                  fullName: 'Сила',
                  value: abilityScores.strength,
                  modifier: abilityScores.strengthModifier,
                ),
              ),
              Expanded(
                child: _AbilityScoreItem(
                  name: 'ЛОВ',
                  fullName: 'Ловкость',
                  value: abilityScores.dexterity,
                  modifier: abilityScores.dexterityModifier,
                ),
              ),
              Expanded(
                child: _AbilityScoreItem(
                  name: 'ТЕЛ',
                  fullName: 'Телосложение',
                  value: abilityScores.constitution,
                  modifier: abilityScores.constitutionModifier,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AbilityScoreItem(
                  name: 'ИНТ',
                  fullName: 'Интеллект',
                  value: abilityScores.intelligence,
                  modifier: abilityScores.intelligenceModifier,
                ),
              ),
              Expanded(
                child: _AbilityScoreItem(
                  name: 'МДР',
                  fullName: 'Мудрость',
                  value: abilityScores.wisdom,
                  modifier: abilityScores.wisdomModifier,
                ),
              ),
              Expanded(
                child: _AbilityScoreItem(
                  name: 'ХАР',
                  fullName: 'Харизма',
                  value: abilityScores.charisma,
                  modifier: abilityScores.charismaModifier,
                ),
              ),
            ],
          ),
        ],
      ),
    );
}

class _AbilityScoreItem extends StatelessWidget {
  const _AbilityScoreItem({
    required this.name,
    required this.fullName,
    required this.value,
    required this.modifier,
  });

  final String name;
  final String fullName;
  final int value;
  final int modifier;

  String get _modifierText {
    if (modifier >= 0) return '+$modifier';
    return '$modifier';
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: '$fullName: $value, модификатор $_modifierText',
      child: Column(
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outline),
            ),
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: modifier >= 0
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _modifierText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: modifier >= 0 ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
}

class _BackstoryCard extends StatelessWidget {
  const _BackstoryCard({required this.backstory});

  final String backstory;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'Предыстория',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            backstory,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.9),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.character,
    this.dndClass,
  });

  final Character character;
  final DndClass? dndClass;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Информация',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.casino,
            label: 'Кость хитов',
            value: dndClass?.hitDie ?? 'd8',
          ),
          _InfoRow(
            icon: Icons.shield,
            label: 'Бонус мастерства',
            value: '+${character.proficiencyBonus}',
          ),
          _InfoRow(
            icon: Icons.calendar_today,
            label: 'Создан',
            value: _formatDate(character.createdAt),
          ),
        ],
      ),
    );

  String _formatDate(DateTime date) => '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.outline),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
}
