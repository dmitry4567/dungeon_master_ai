import 'dart:math' as math;

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

/// Страница входа/регистрации — тёмный фэнтези стиль
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: _handleStateChange,
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Stack(
              children: [
                // Фон — звёздное поле
                const _StarField(),

                // Градиентный оверлей снизу
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0D0D1A).withValues(alpha: 0),
                          const Color(0xFF0D0D1A).withValues(alpha: 0.95),
                          const Color(0xFF0D0D1A),
                        ],
                      ),
                    ),
                  ),
                ),

                // Контент
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 60),

                        // Логотип и заголовок
                        _buildHeader(),

                        const SizedBox(height: 48),

                        // Форма
                        _buildFormCard(isLoading, context),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _buildHeader() => Column(
        children: [
          // Орнаментальный логотип
          _GlowingIcon(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A2E),
                border: Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories,
                size: 44,
                color: Color(0xFFD4AF37),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Декоративная линия над заголовком
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ornamentLine(),
              const SizedBox(width: 12),
              Text(
                'AI DUNGEON MASTER',
                style: AppTypography.headlineLarge.copyWith(
                  color: const Color(0xFFD4AF37),
                  fontSize: 22,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              _ornamentLine(),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Начни своё приключение',
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _ornamentLine() => Row(
        children: [
          Container(
            width: 20,
            height: 1,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFD4AF37),
              shape: BoxShape.circle,
            ),
          ),
        ],
      );

  Widget _buildFormCard(bool isLoading, BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF13132A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF2A2A4E),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Apple Sign In
            AppleSignInButton(
              onPressed: () => context
                  .read<AuthBloc>()
                  .add(const AuthEvent.signInWithApple()),
              isLoading: isLoading,
            ),

            const SizedBox(height: 20),

            // Разделитель
            _buildDivider(),

            const SizedBox(height: 20),

            // Email форма
            EmailLoginForm(
              isLoading: isLoading,
              onLogin: (email, password) => context
                  .read<AuthBloc>()
                  .add(AuthEvent.loginWithEmail(
                    email: email,
                    password: password,
                  ),),
              onRegister: (email, password, name) =>
                  context.read<AuthBloc>().add(AuthEvent.register(
                        email: email,
                        password: password,
                        name: name,
                      ),),
            ),
          ],
        ),
      );

  Widget _buildDivider() => Row(
        children: [
          const Expanded(
            child: Divider(
              color: Color(0xFF2A2A4E),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'или',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white38,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              color: Color(0xFF2A2A4E),
              thickness: 1,
            ),
          ),
        ],
      );

  void _handleStateChange(BuildContext context, AuthState state) {
    state.whenOrNull(
      authenticated: (user) {
        context.go(Routes.lobby);
      },
      error: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// Виджет пульсирующего свечения иконки
// ─────────────────────────────────────────────────
class _GlowingIcon extends StatefulWidget {
  const _GlowingIcon({required this.child});
  final Widget child;

  @override
  State<_GlowingIcon> createState() => _GlowingIconState();
}

class _GlowingIconState extends State<_GlowingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _glow,
        builder: (_, child) => Opacity(
          opacity: _glow.value,
          child: child,
        ),
        child: Center(child: widget.child),
      );
}

// ─────────────────────────────────────────────────
// Звёздный фон
// ─────────────────────────────────────────────────
class _StarField extends StatefulWidget {
  const _StarField();

  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _stars = List.generate(80, (_) => _Star(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _StarPainter(_stars, _ctrl.value),
          size: MediaQuery.of(context).size,
        ),
      );
}

class _Star {
  _Star(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        radius = rng.nextDouble() * 1.5 + 0.3,
        phase = rng.nextDouble();

  final double x;
  final double y;
  final double radius;
  final double phase;
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.progress);
  final List<_Star> stars;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final star in stars) {
      final opacity =
          (math.sin((progress + star.phase) * 2 * math.pi) * 0.3 + 0.5)
              .clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: opacity * 0.8);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height * 0.6),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.progress != progress;
}
