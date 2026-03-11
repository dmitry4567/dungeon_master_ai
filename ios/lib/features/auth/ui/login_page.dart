import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'widgets/apple_sign_in_button.dart';
import 'widgets/email_login_form.dart';

/// Страница входа/регистрации
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: _handleStateChange,
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: _buildFormCard(context, isLoading),
                  ),
                ),
              ],
            );
          },
        ),
      );

  // ── AppBar в стиле профиля/сценариев ──────────────────────────────────────
  SliverAppBar _buildSliverAppBar(BuildContext context) => SliverAppBar(
        expandedHeight: 240,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        flexibleSpace: FlexibleSpaceBar(
          background: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A3E), Color(0xFF0D0D1A)],
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
                    padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Иконка — точно как в scenario_list_page
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
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_stories,
                            color: Color(0xFFD4AF37),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'AI Dungeon Master',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Начни своё приключение',
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

  // ── Карточка с формой — стиль карточек сценариев ──────────────────────────
  Widget _buildFormCard(BuildContext context, bool isLoading) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Apple Sign In
            AppleSignInButton(
              onPressed: () => context
                  .read<AuthBloc>()
                  .add(const AuthSignInWithApple()),
              isLoading: isLoading,
            ),

            const SizedBox(height: 16),

            // Разделитель
            Row(
              children: [
                const Expanded(
                  child: Divider(color: Color(0xFF2A2A4E), thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'или',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white38,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: Color(0xFF2A2A4E), thickness: 1),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Email форма
            EmailLoginForm(
              isLoading: isLoading,
              onLogin: (email, password) => context
                  .read<AuthBloc>()
                  .add(AuthLoginWithEmail(
                    email: email,
                    password: password,
                  ),),
              onRegister: (email, password, name) =>
                  context.read<AuthBloc>().add(AuthRegister(
                        email: email,
                        password: password,
                        name: name,
                      ),),
            ),
          ],
        ),
      );

  void _handleStateChange(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      context.go(Routes.lobby);
    } else if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// Идентичен _StarFieldPainter из profile_page.dart / scenario_list_page.dart
class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
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
