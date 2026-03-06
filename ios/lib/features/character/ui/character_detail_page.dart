import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../bloc/character_bloc.dart';
import '../bloc/character_event.dart';
import '../bloc/character_state.dart';
import '../data/dnd_reference_data.dart';
import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/dnd_data.dart';

/// Страница просмотра персонажа
class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({
    required this.characterId,
    super.key,
  });

  final String characterId;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    context.read<CharacterBloc>().add(
          CharacterEvent.loadCharacter(id: widget.characterId),
        );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CharacterBloc, CharacterState>(
        listener: (context, state) {
          if (state is CharacterDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Персонаж удалён'),
                backgroundColor: Color(0xFF52B788),
              ),
            );
            context.go(Routes.characters);
          } else if (state is CharacterError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF8B3333),
              ),
            );
          }
        },
        builder: (context, state) => switch (state) {
          CharacterLoading() => _buildLoadingView(),
          CharacterDetail(:final character) => _buildCharacterView(character),
          CharacterError(:final message) => _buildErrorView(message),
          _ => _buildLoadingView(),
        },
      );

  Widget _buildLoadingView() => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(null),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LoadingSkeleton(height: 100, borderRadius: 12),
                  ),
                  childCount: 5,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildErrorView(String message) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(null),
            SliverFillRemaining(
              child: ErrorView(
                message: message,
                onRetry: () {
                  context.read<CharacterBloc>().add(
                        CharacterEvent.loadCharacter(id: widget.characterId),
                      );
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildCharacterView(Character character) {
    final dndClass = DndReferenceData.findClassById(character.characterClass);
    final dndRace = DndReferenceData.findRaceById(character.race);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(character),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Основная информация
                  _buildHeaderCard(character, dndClass, dndRace),
                  const SizedBox(height: 16),
                  // Характеристики
                  _buildAbilityScoresCard(character.abilityScores),
                  const SizedBox(height: 16),
                  // Предыстория
                  if (character.backstory != null &&
                      character.backstory!.isNotEmpty) ...[
                    _buildBackstoryCard(character.backstory!),
                    const SizedBox(height: 16),
                  ],
                  // Дополнительная информация
                  _buildInfoCard(character, dndClass),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // _buildBottomNavigationBar(character),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Character? character) => SliverAppBar(
        expandedHeight: 265,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        actions: [
          if (character != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _showActionsMenu(character),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Color(0xFFD4AF37),
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A3E),
                  Color(0xFF0D0D1A),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _StarFieldPainter()),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2A2A4A),
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.4),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              character != null
                                  ? (DndReferenceData.findClassById(
                                              character.characterClass,)
                                          ?.iconEmoji ??
                                      '⚔️')
                                  : '⚔️',
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          character?.name ?? 'Загрузка...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          character != null
                              ? '${DndReferenceData.findRaceById(character.race)?.nameRu ?? character.race} • ${DndReferenceData.findClassById(character.characterClass)?.nameRu ?? character.characterClass}'
                              : '',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildBottomNavigationBar(Character character) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A4E), width: 1.5),
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.go(Routes.lobby);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFD4AF37).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF52B788).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Color(0xFF52B788),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Играть',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildHeaderCard(
          Character character, DndClass? dndClass, dynamic dndRace,) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD4AF37).withOpacity(0.1),
              const Color(0xFFD4AF37).withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Информация',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow(
                        icon: Icons.star,
                        label: 'Уровень',
                        value: '${character.level}',
                        valueColor: const Color(0xFFF4A261),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        icon: Icons.favorite,
                        label: 'Здоровье',
                        value: '${character.maxHitPoints} HP',
                        valueColor: const Color(0xFFE76F51),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 20,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow(
                        icon: Icons.shield_outlined,
                        label: 'Бонус мастерства',
                        value: '+${character.proficiencyBonus}',
                        valueColor: const Color(0xFF52B788),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        icon: Icons.casino,
                        label: 'Кость хитов',
                        value: dndClass?.hitDie ?? 'd8',
                        valueColor: const Color(0xFF2A9D8F),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) =>
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: valueColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );

  Widget _buildAbilityScoresCard(AbilityScores abilityScores) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Характеристики',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAbilityScoreItem(
                    name: 'СИЛ',
                    value: abilityScores.strength,
                    modifier: abilityScores.strengthModifier,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAbilityScoreItem(
                    name: 'ЛОВ',
                    value: abilityScores.dexterity,
                    modifier: abilityScores.dexterityModifier,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAbilityScoreItem(
                    name: 'ТЕЛ',
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
                  child: _buildAbilityScoreItem(
                    name: 'ИНТ',
                    value: abilityScores.intelligence,
                    modifier: abilityScores.intelligenceModifier,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAbilityScoreItem(
                    name: 'МДР',
                    value: abilityScores.wisdom,
                    modifier: abilityScores.wisdomModifier,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAbilityScoreItem(
                    name: 'ХАР',
                    value: abilityScores.charisma,
                    modifier: abilityScores.charismaModifier,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildAbilityScoreItem({
    required String name,
    required int value,
    required int modifier,
  }) {
    final modifierText = modifier >= 0 ? '+$modifier' : '$modifier';
    final isPositive = modifier >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A4E)),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A4A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3A3A5E)),
            ),
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF52B788).withOpacity(0.15)
                  : const Color(0xFFE76F51).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isPositive
                    ? const Color(0xFF52B788).withOpacity(0.4)
                    : const Color(0xFFE76F51).withOpacity(0.4),
              ),
            ),
            child: Text(
              modifierText,
              style: TextStyle(
                color: isPositive
                    ? const Color(0xFF52B788)
                    : const Color(0xFFE76F51),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackstoryCard(String backstory) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Предыстория',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              backstory,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      );

  Widget _buildInfoCard(Character character, DndClass? dndClass) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Дополнительно',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Создан',
              value: _formatDate(character.createdAt),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.update,
              label: 'Обновлён',
              value: character.updatedAt != null
                  ? _formatDate(character.updatedAt!)
                  : '—',
            ),
          ],
        ),
      );

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFFD4AF37)),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  String _formatDate(DateTime date) =>
      '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  void _showActionsMenu(Character character) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A5E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Color(0xFFE76F51)),
                title: const Text(
                  'Удалить',
                  style: TextStyle(color: Color(0xFFE76F51)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(character);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Character character) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Удалить персонажа?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Персонаж "${character.name}" будет удалён безвозвратно.',
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE76F51),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CharacterBloc>().add(
                    CharacterEvent.deleteCharacter(id: character.id),
                  );
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);

    final positions = [
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.1),
      Offset(size.width * 0.7, size.height * 0.15),
      Offset(size.width * 0.9, size.height * 0.3),
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.85, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.05),
    ];

    for (final pos in positions) {
      canvas.drawCircle(pos, 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
