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
        body: SafeArea(
          child: BlocConsumer<AuthBloc, AuthState>(
            listener: _handleStateChange,
            builder: (context, state) {
              final isLoading = state is AuthLoading;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),

                    // Logo and title
                    _buildHeader(),

                    const SizedBox(height: 48),

                    // Apple Sign In
                    AppleSignInButton(
                      onPressed: () => context
                          .read<AuthBloc>()
                          .add(const AuthEvent.signInWithApple()),
                      isLoading: isLoading,
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    _buildDivider(),

                    const SizedBox(height: 24),

                    // Email form
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
            },
          ),
        ),
      );

  Widget _buildHeader() => Column(
        children: [
          // Icon/Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI Dungeon Master',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Начни своё приключение',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildDivider() => Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.outline.withValues(alpha: 0.3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'или',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.outline),
            ),
          ),
          Expanded(
            child: Divider(color: AppColors.outline.withValues(alpha: 0.3)),
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
          ),
        );
      },
    );
  }
}
