import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_dungeon_master/features/auth/bloc/auth_bloc.dart';
import 'package:ai_dungeon_master/features/auth/bloc/auth_event.dart';
import 'package:ai_dungeon_master/features/auth/bloc/auth_state.dart';
import 'package:ai_dungeon_master/features/auth/ui/login_page.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

class FakeAuthState extends Fake implements AuthState {}

void main() {
  late AuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(FakeAuthState());
  });

  setUp(() {
    authBloc = MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthState.unauthenticated());
  });

  tearDown(() {
    authBloc.close();
  });

  Widget buildTestWidget() => MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const LoginPage(),
        ),
      );

  group('LoginPage', () {
    testWidgets('renders login form', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('AI Dungeon Master'), findsOneWidget);
      expect(find.text('Войти через Apple'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Пароль'), findsOneWidget);
      expect(find.text('Войти'), findsOneWidget);
    });

    testWidgets('shows register fields when toggle is pressed', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Initially no name field
      expect(find.text('Имя'), findsNothing);

      // Tap register toggle
      await tester.tap(find.text('Нет аккаунта? Зарегистрироваться'));
      await tester.pumpAndSettle();

      // Now name field should appear
      expect(find.text('Имя'), findsOneWidget);
      expect(find.text('Зарегистрироваться'), findsOneWidget);
    });

    testWidgets('validates email format', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField).first, 'invalid');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      expect(find.text('Некорректный email'), findsOneWidget);
    });

    testWidgets('validates password length', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Enter valid email
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      // Enter short password
      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      expect(
        find.text('Пароль должен быть не менее 6 символов'),
        findsOneWidget,
      );
    });

    testWidgets('calls loginWithEmail on valid submit', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Enter valid credentials
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      await tester.tap(find.text('Войти'));
      await tester.pump();

      verify(
        () => authBloc.add(
          const AuthEvent.loginWithEmail(
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      ).called(1);
    });

    testWidgets('calls signInWithApple when Apple button pressed',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Войти через Apple'));
      await tester.pump();

      verify(() => authBloc.add(const AuthEvent.signInWithApple())).called(1);
    });

    testWidgets('shows loading indicator when state is loading',
        (tester) async {
      when(() => authBloc.state).thenReturn(const AuthState.loading());

      await tester.pumpWidget(buildTestWidget());

      // Button should show loading state (disabled)
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNull);
    });
  });
}
