import 'package:ai_dungeon_master/core/theme/colors.dart';
import 'package:ai_dungeon_master/features/auth/bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';

/// Главный виджет приложения
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = getIt<AppRouter>();

    // Используем singleton AuthBloc и запускаем проверку сессии
    final authBloc = getIt<AuthBloc>()..add(const AuthEvent.checkSession());

    return BlocProvider.value(
      value: authBloc,
      child: MaterialApp.router(
        title: 'AI Dungeon Master',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark.copyWith(
          appBarTheme: const AppBarTheme(
            scrolledUnderElevation: 0,
            backgroundColor: AppColors.background,
          ),
        ),
        routerConfig: appRouter.router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1).clamp(0.8, 1.4),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
