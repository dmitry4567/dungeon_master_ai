import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_dungeon_master/features/auth/bloc/auth_bloc.dart';
import 'package:ai_dungeon_master/features/auth/bloc/auth_event.dart';
import 'package:ai_dungeon_master/features/auth/bloc/auth_state.dart';
import 'package:ai_dungeon_master/features/auth/data/auth_repository.dart';
import 'package:ai_dungeon_master/features/auth/models/user.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AuthRepository authRepository;
  late AuthBloc authBloc;

  final testUser = User(
    id: 'user-123',
    email: 'test@example.com',
    name: 'Test User',
    createdAt: DateTime.now(),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    authBloc = AuthBloc(authRepository);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, const AuthState.initial());
    });

    group('CheckSession', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when session exists',
        build: () {
          when(() => authRepository.checkSession())
              .thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.checkSession()),
        expect: () => [
          const AuthState.loading(),
          AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] when no session',
        build: () {
          when(() => authRepository.checkSession())
              .thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.checkSession()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] when checkSession throws',
        build: () {
          when(() => authRepository.checkSession()).thenThrow(Exception());
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.checkSession()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );
    });

    group('LoginWithEmail', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when login succeeds',
        build: () {
          when(
            () => authRepository.loginWithEmail(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.loginWithEmail(
          email: 'test@example.com',
          password: 'password123',
        )),
        expect: () => [
          const AuthState.loading(),
          AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when login fails',
        build: () {
          when(
            () => authRepository.loginWithEmail(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(Exception('Invalid credentials'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.loginWithEmail(
          email: 'test@example.com',
          password: 'wrong',
        )),
        expect: () => [
          const AuthState.loading(),
          isA<AuthError>(),
        ],
      );
    });

    group('Register', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when registration succeeds',
        build: () {
          when(
            () => authRepository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
              name: any(named: 'name'),
            ),
          ).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.register(
          email: 'test@example.com',
          password: 'password123',
          name: 'Test User',
        )),
        expect: () => [
          const AuthState.loading(),
          AuthState.authenticated(testUser),
        ],
      );
    });

    group('SignInWithApple', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when Apple sign in succeeds',
        build: () {
          when(() => authRepository.signInWithApple())
              .thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.signInWithApple()),
        expect: () => [
          const AuthState.loading(),
          AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] when user cancels',
        build: () {
          when(() => authRepository.signInWithApple())
              .thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.signInWithApple()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );
    });

    group('Logout', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] when logout succeeds',
        build: () {
          when(() => authRepository.logout()).thenAnswer((_) async {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.logout()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] even when logout fails',
        build: () {
          when(() => authRepository.logout()).thenThrow(Exception());
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthEvent.logout()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );
    });
  });
}
