import 'package:ai_dungeon_master/features/game_session/bloc/tts_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/interceptors/error_interceptor.dart';
import '../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC аутентификации
@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState.initial()) {
    on<AuthCheckSession>(_onCheckSession);
    on<AuthLoginWithEmail>(_onLoginWithEmail);
    on<AuthRegister>(_onRegister);
    on<AuthSignInWithApple>(_onSignInWithApple);
    on<AuthLogout>(_onLogout);
  }

  final AuthRepository _authRepository;

  Future<void> _onCheckSession(
    AuthCheckSession event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    try {
      final user = await _authRepository.checkSession();
      if (user != null) {
        emit(AuthState.authenticated(user));
      } else {
        emit(const AuthState.unauthenticated());
      }
    } catch (e) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLoginWithEmail(
    AuthLoginWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    try {
      final user = await _authRepository.loginWithEmail(
        email: event.email,
        password: event.password,
      );
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.error(_extractErrorMessage(e)));
    }
  }

  Future<void> _onRegister(
    AuthRegister event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    try {
      final user = await _authRepository.register(
        email: event.email,
        password: event.password,
        name: event.name,
      );
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.error(_extractErrorMessage(e)));
    }
  }

  Future<void> _onSignInWithApple(
    AuthSignInWithApple event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    try {
      final user = await _authRepository.signInWithApple();
      if (user != null) {
        emit(AuthState.authenticated(user));
      } else {
        // Пользователь отменил
        emit(const AuthState.unauthenticated());
      }
    } catch (e) {
      emit(AuthState.error(_extractErrorMessage(e)));
    }
  }

  Future<void> _onLogout(
    AuthLogout event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    try {
      await _authRepository.logout();
      getIt<TTSCubit>().clearState();
      emit(const AuthState.unauthenticated());
    } catch (e) {
      // Всё равно выходим
      getIt<TTSCubit>().clearState();
      emit(const AuthState.unauthenticated());
    }
  }

  String _extractErrorMessage(Object error) {
    if (error is ApiError) {
      return error.message;
    }
    return 'Произошла ошибка. Попробуйте позже.';
  }
}
