import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

/// BLoC профиля пользователя
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._profileRepository) : super(const ProfileState.initial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<LoadHistoryEvent>(_onLoadHistory);
    on<UpdateNameEvent>(_onUpdateName);
    on<UpdateAvatarEvent>(_onUpdateAvatar);
    on<ClearErrorEvent>(_onClearError);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileState.loading());

    try {
      final user = await _profileRepository.getProfile();
      final currentState = state;
      if (currentState is ProfileLoaded) {
        emit(currentState.copyWith(user: user));
      } else {
        emit(ProfileState.loaded(
          user: user,
          history: [],
          isHistoryLoading: false,
          isUpdating: false,
        ));
      }
    } catch (e) {
      emit(ProfileState.error(
        message: e.toString(),
        previousState: state,
      ));
    }
  }

  Future<void> _onLoadHistory(
    LoadHistoryEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(currentState.copyWith(isHistoryLoading: true));

    try {
      final history = await _profileRepository.getGameHistory();
      final newState = state;
      if (newState is ProfileLoaded) {
        emit(newState.copyWith(
          history: history,
          isHistoryLoading: false,
        ));
      }
    } catch (e) {
      final newState = state;
      if (newState is ProfileLoaded) {
        emit(newState.copyWith(isHistoryLoading: false));
      }
    }
  }

  Future<void> _onUpdateName(
    UpdateNameEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(currentState.copyWith(isUpdating: true));

    try {
      final updatedUser = await _profileRepository.updateName(event.name);
      final newState = state;
      if (newState is ProfileLoaded) {
        emit(newState.copyWith(
          user: updatedUser,
          isUpdating: false,
        ));
      }
    } catch (e) {
      emit(ProfileState.error(
        message: e.toString(),
        previousState: state,
      ));
    }
  }

  Future<void> _onUpdateAvatar(
    UpdateAvatarEvent event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(currentState.copyWith(isUpdating: true));

    try {
      final updatedUser = await _profileRepository.updateAvatar(event.avatarUrl);
      final newState = state;
      if (newState is ProfileLoaded) {
        emit(newState.copyWith(
          user: updatedUser,
          isUpdating: false,
        ));
      }
    } catch (e) {
      emit(ProfileState.error(
        message: e.toString(),
        previousState: state,
      ));
    }
  }

  void _onClearError(
    ClearErrorEvent event,
    Emitter<ProfileState> emit,
  ) {
    final currentState = state;
    if (currentState is ProfileError && currentState.previousState != null) {
      emit(currentState.previousState!);
    }
  }
}
