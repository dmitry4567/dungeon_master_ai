import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../bloc/character_bloc.dart';
import '../bloc/character_event.dart';
import '../bloc/character_state.dart';
import '../models/character.dart';
import 'widgets/character_card.dart';

/// Страница списка персонажей
class CharacterListPage extends StatelessWidget {
  const CharacterListPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: BlocConsumer<CharacterBloc, CharacterState>(
          listener: (context, state) {
            if (state is CharacterDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Персонаж удалён'),
                  backgroundColor: Color(0xFF2D6A4F),
                ),
              );
              context.read<CharacterBloc>().add(
                    const CharacterEvent.loadCharacters(),
                  );
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
            CharacterLoading() => _buildLoading(),
            CharacterLoaded(:final characters) => _buildLoaded(context, characters),
            CharacterError(:final message) => _buildError(context, message),
            _ => _buildLoading(),
          },
        ),
      );

  Widget _buildLoading() => CustomScrollView(
        slivers: [
          _buildSliverAppBar(null),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _SkeletonCard(),
                ),
                childCount: 3,
              ),
            ),
          ),
        ],
      );

  Widget _buildError(BuildContext context, String message) => CustomScrollView(
        slivers: [
          _buildSliverAppBar(null),
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 56,
                      color: Color(0xFF8B3333),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => context.read<CharacterBloc>().add(
                            const CharacterEvent.loadCharacters(),
                          ),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildLoaded(BuildContext context, List<Character> characters) =>
      RefreshIndicator(
        color: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF1A1A2E),
        onRefresh: () async {
          context.read<CharacterBloc>().add(
                const CharacterEvent.loadCharacters(forceRefresh: true),
              );
          await context.read<CharacterBloc>().stream.firstWhere(
                (s) => s is CharacterLoaded || s is CharacterError,
              );
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            if (characters.isEmpty)
              const SliverFillRemaining(child: _EmptyView())
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: Color(0xFFD4AF37),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Мои персонажи',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4,),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${characters.length}',
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final character = characters[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CharacterCard(
                          character: character,
                          onTap: () => context
                              .push(Routes.characterDetailPath(character.id)),
                          onLongPress: () =>
                              _showCharacterOptions(context, character),
                        ),
                      );
                    },
                    childCount: characters.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildSliverAppBar(BuildContext? context) => SliverAppBar(
        expandedHeight: 242,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        actions: context == null
            ? null
            : [
                _CreateButton(
                  onPressed: () async {
                    final result = await context.push(Routes.characterCreate);
                    if (result == true && context.mounted) {
                      context.read<CharacterBloc>().add(
                            const CharacterEvent.loadCharacters(
                                forceRefresh: true,),
                          );
                    }
                  },
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
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2A2A4A),
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield,
                            color: Color(0xFFD4AF37),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Персонажи',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Герои вашего приключения',
                          style: TextStyle(
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

  void _showCharacterOptions(BuildContext context, Character character) {
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
                leading: const Icon(Icons.visibility,
                    color: Color(0xFFD4AF37),),
                title: const Text(
                  'Просмотреть',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(Routes.characterDetailPath(character.id));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete,
                    color: Color(0xFFE57373),),
                title: const Text(
                  'Удалить',
                  style: TextStyle(color: Color(0xFFE57373)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, character);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Character character) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Удалить персонажа?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Персонаж "${character.name}" будет удалён безвозвратно.',
          style: const TextStyle(color: Colors.white70),
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
              backgroundColor: const Color(0xFF8B3333),
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

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: Color(0xFFD4AF37)),
                SizedBox(width: 4),
                Text(
                  'Создать',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_add_outlined,
                size: 56,
                color: Color(0xFF3A3A5E),
              ),
              const SizedBox(height: 16),
              const Text(
                'Нет персонажей',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Создайте своего первого героя,\nчтобы начать приключение',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
      );
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

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
