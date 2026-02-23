import 'package:ai_dungeon_master/features/auth/bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/character/bloc/character_bloc.dart';
import '../../features/character/bloc/character_event.dart';
import '../../features/character/ui/character_create_page.dart';
import '../../features/character/ui/character_detail_page.dart';
import '../../features/character/ui/character_list_page.dart';
import '../../features/lobby/bloc/lobby_bloc.dart';
import '../../features/lobby/bloc/lobby_event.dart';
import '../../features/lobby/ui/lobby_page.dart';
import '../../features/lobby/ui/room_create_page.dart';
import '../../features/lobby/ui/waiting_room_page.dart';
import '../../features/scenario/bloc/scenario_bloc.dart';
import '../../features/scenario/bloc/scenario_event.dart';
import '../../features/game_session/bloc/game_session_bloc.dart';
import '../../features/game_session/bloc/game_session_event.dart';
import '../../features/game_session/ui/game_session_page.dart';
import '../../features/scenario/ui/scenario_builder_page.dart';
import '../../features/scenario/ui/scenario_list_page.dart';
import '../../features/scenario/ui/scenario_preview_page.dart';
import '../di/injection.dart';
import '../storage/secure_storage.dart';
import 'routes.dart';

/// Конфигурация go_router
@lazySingleton
class AppRouter {
  AppRouter(this._secureStorage);

  final SecureStorage _secureStorage;

  late final GoRouter router = GoRouter(
    initialLocation: Routes.login,
    debugLogDiagnostics: true,
    redirect: _guardRoute,
    routes: [
      // Auth routes
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register,
        name: 'register',
        builder: (context, state) => const LoginPage(),
      ),

      // Main shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          // Lobby tab
          GoRoute(
            path: Routes.lobby,
            name: 'lobby',
            pageBuilder: (context, state) => NoTransitionPage(
              child: BlocProvider(
                create: (_) => getIt<LobbyBloc>()
                  ..add(const LobbyEvent.loadRooms()),
                child: const LobbyPage(),
              ),
            ),
            routes: [
              GoRoute(
                path: 'create',
                name: 'roomCreate',
                builder: (context, state) => MultiBlocProvider(
                  providers: [
                    BlocProvider(create: (_) => getIt<LobbyBloc>()),
                    BlocProvider(create: (_) => getIt<ScenarioBloc>()),
                  ],
                  child: const RoomCreatePage(),
                ),
              ),
              GoRoute(
                path: 'room/:roomId',
                name: 'waitingRoom',
                builder: (context, state) {
                  final roomId = state.pathParameters['roomId']!;
                  return BlocProvider(
                    create: (_) => getIt<LobbyBloc>()
                      ..add(LobbyEvent.loadRoom(roomId: roomId)),
                    child: WaitingRoomPage(roomId: roomId),
                  );
                },
              ),
            ],
          ),

          // Scenarios tab
          GoRoute(
            path: Routes.scenarios,
            name: 'scenarios',
            pageBuilder: (context, state) => NoTransitionPage(
              child: BlocProvider(
                create: (_) => getIt<ScenarioBloc>()
                  ..add(const ScenarioEvent.loadScenarios()),
                child: const ScenarioListPage(),
              ),
            ),
            routes: [
              GoRoute(
                path: 'builder',
                name: 'scenarioBuilder',
                builder: (context, state) => BlocProvider(
                  create: (_) => getIt<ScenarioBloc>(),
                  child: const ScenarioBuilderPage(),
                ),
              ),
              GoRoute(
                path: ':scenarioId',
                name: 'scenarioPreview',
                builder: (context, state) {
                  final scenarioId = state.pathParameters['scenarioId']!;
                  return BlocProvider(
                    create: (_) => getIt<ScenarioBloc>()
                      ..add(ScenarioEvent.loadScenario(id: scenarioId)),
                    child: ScenarioPreviewPage(scenarioId: scenarioId),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'refine',
                    name: 'scenarioRefine',
                    builder: (context, state) {
                      final scenarioId = state.pathParameters['scenarioId']!;
                      return BlocProvider(
                        create: (_) => getIt<ScenarioBloc>(),
                        child: ScenarioBuilderPage(scenarioId: scenarioId),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Characters tab
          GoRoute(
            path: Routes.characters,
            name: 'characters',
            pageBuilder: (context, state) => NoTransitionPage(
              child: BlocProvider(
                create: (_) => getIt<CharacterBloc>()
                  ..add(const CharacterEvent.loadCharacters()),
                child: const CharacterListPage(),
              ),
            ),
            routes: [
              GoRoute(
                path: 'create',
                name: 'characterCreate',
                builder: (context, state) => BlocProvider(
                  create: (_) => getIt<CharacterBloc>()
                    ..add(const CharacterEvent.startCreation()),
                  child: const CharacterCreatePage(),
                ),
              ),
              GoRoute(
                path: ':characterId',
                name: 'characterDetail',
                builder: (context, state) {
                  final characterId = state.pathParameters['characterId']!;
                  return BlocProvider(
                    create: (_) => getIt<CharacterBloc>(),
                    child: CharacterDetailPage(characterId: characterId),
                  );
                },
              ),
            ],
          ),

          // Profile tab
          GoRoute(
            path: Routes.profile,
            name: 'profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: _PlaceholderPage(title: 'Profile'),
            ),
            routes: [
              GoRoute(
                path: 'settings',
                name: 'settings',
                builder: (context, state) =>
                    const _PlaceholderPage(title: 'Settings'),
              ),
            ],
          ),
        ],
      ),

      // Game session (fullscreen, outside shell)
      GoRoute(
        path: '/game/:roomId',
        name: 'gameSession',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return BlocProvider(
            create: (_) => getIt<GameSessionBloc>()
              ..add(GameSessionEvent.connectToSession(roomId: roomId)),
            child: GameSessionPage(roomId: roomId),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => _ErrorPage(error: state.error),
  );

  /// Guard routes based on authentication
  Future<String?> _guardRoute(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isAuthenticated = await _secureStorage.hasTokens();
    final isAuthRoute = state.matchedLocation == Routes.login ||
        state.matchedLocation == Routes.register;

    // Not authenticated - redirect to login
    if (!isAuthenticated && !isAuthRoute) {
      return Routes.login;
    }

    // Authenticated but on auth route - redirect to lobby
    if (isAuthenticated && isAuthRoute) {
      return Routes.lobby;
    }

    return null;
  }
}

/// Main shell with bottom navigation
class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(location),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_arrow_outlined),
            selectedIcon: Icon(Icons.play_arrow),
            label: 'Играть',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Сценарии',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Персонажи',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(String location) {
    if (location.startsWith(Routes.lobby)) return 0;
    if (location.startsWith(Routes.scenarios)) return 1;
    if (location.startsWith(Routes.characters)) return 2;
    if (location.startsWith(Routes.profile)) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(Routes.lobby);
      case 1:
        context.go(Routes.scenarios);
      case 2:
        context.go(Routes.characters);
      case 3:
        context.go(Routes.profile);
    }
  }
}

/// Placeholder page for routes not yet implemented
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: GestureDetector(
            onTap: () {
              getIt<AuthBloc>().add(const AuthEvent.logout());
            },
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
      );
}

/// Error page
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Страница не найдена',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (error != null)
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(Routes.lobby),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      );
}
