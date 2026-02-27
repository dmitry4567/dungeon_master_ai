import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/models/user.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import 'widgets/game_history_card.dart';

/// Страница профиля пользователя
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) => state.when(
            initial: () => _buildInitialState(context),
            loading: _buildLoadingState,
            loaded: (user, history, isHistoryLoading, isUpdating) =>
                RefreshIndicator(
              color: const Color(0xFFD4AF37),
              backgroundColor: const Color(0xFF1A1A2E),
              onRefresh: () async {
                context
                    .read<ProfileBloc>()
                    .add(const ProfileEvent.loadProfile());
                context
                    .read<ProfileBloc>()
                    .add(const ProfileEvent.loadHistory());
              },
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(context, user, isUpdating),
                  SliverToBoxAdapter(
                    child: _buildStatsRow(context, history.length),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_stories,
                            color: Color(0xFFD4AF37),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'История приключений',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const Spacer(),
                          if (isHistoryLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (history.isEmpty && !isHistoryLoading)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: _buildEmptyHistory(context),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GameHistoryCard(game: history[index]),
                          ),
                          childCount: history.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            error: (message, _) => _buildErrorState(context, message),
          ),
        ),
      );

  Widget _buildSliverAppBar(BuildContext context, User user, bool isUpdating) =>
      SliverAppBar(
        expandedHeight: 280,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => context.pushNamed('settings'),
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
                // Decorative background pattern
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StarFieldPainter(),
                  ),
                ),
                // Profile content
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
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
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFF2A2A4A),
                            child: user.avatarUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      user.avatarUrl!,
                                      width: 104,
                                      height: 104,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      color: Color(0xFFD4AF37),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (isUpdating)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFD4AF37),
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ActionButton(
                                icon: Icons.edit_outlined,
                                label: 'Изменить имя',
                                onPressed: () =>
                                    _showEditNameDialog(context, user.name),
                              ),
                              const SizedBox(width: 12),
                              _ActionButton(
                                icon: Icons.logout_outlined,
                                label: 'Выйти',
                                isDestructive: true,
                                onPressed: () {
                                  context
                                      .read<AuthBloc>()
                                      .add(const AuthEvent.logout());
                                },
                              ),
                            ],
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

  Widget _buildStatsRow(BuildContext context, int gamesCount) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(
              value: gamesCount.toString(),
              label: 'Игр сыграно',
              icon: Icons.sports_esports_outlined,
            ),
            _buildDivider(),
            const _StatItem(
              value: '—',
              label: 'Побед',
              icon: Icons.emoji_events_outlined,
            ),
            _buildDivider(),
            const _StatItem(
              value: '—',
              label: 'Часов',
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
      );

  Widget _buildDivider() => Container(
        width: 1,
        height: 40,
        color: const Color(0xFF2A2A4E),
      );

  Widget _buildEmptyHistory(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.map_outlined,
              size: 56,
              color: Color(0xFF3A3A5E),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ни одного приключения',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Начните своё первое путешествие в мире D&D',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildInitialState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline,
                size: 64, color: Color(0xFF3A3A5E),),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                context
                    .read<ProfileBloc>()
                    .add(const ProfileEvent.loadProfile());
                context
                    .read<ProfileBloc>()
                    .add(const ProfileEvent.loadHistory());
              },
              child: const Text('Загрузить профиль'),
            ),
          ],
        ),
      );

  Widget _buildLoadingState() => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );

  Widget _buildErrorState(BuildContext context, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: Color(0xFF8B3333),),
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
                ),
                onPressed: () {
                  context
                      .read<ProfileBloc>()
                      .add(const ProfileEvent.loadProfile());
                  context
                      .read<ProfileBloc>()
                      .add(const ProfileEvent.loadHistory());
                },
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    final profileBloc = context.read<ProfileBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Изменить имя',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Ваше имя',
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A2A4E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD4AF37)),
            ),
            filled: true,
            fillColor: const Color(0xFF0D0D1A),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              profileBloc.add(ProfileEvent.updateName(value.trim()));
              Navigator.pop(dialogContext);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                profileBloc
                    .add(ProfileEvent.updateName(controller.text.trim()));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Сохранить',
                style: TextStyle(fontWeight: FontWeight.bold),),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFF8B3333).withOpacity(0.2)
                : const Color(0xFFD4AF37).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDestructive
                  ? const Color(0xFF8B3333).withOpacity(0.5)
                  : const Color(0xFFD4AF37).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDestructive
                    ? const Color(0xFFE57373)
                    : const Color(0xFFD4AF37),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive
                      ? const Color(0xFFE57373)
                      : const Color(0xFFD4AF37),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      );
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    // Simple decorative dots pattern
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
