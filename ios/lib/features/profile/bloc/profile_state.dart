import '../../auth/models/user.dart';
import '../models/game_history.dart';

/// Состояния ProfileBloc
abstract class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final User user;
  final List<GameHistory> history;
  final bool isHistoryLoading;
  final bool isUpdating;

  const ProfileLoaded({
    required this.user,
    required this.history,
    required this.isHistoryLoading,
    required this.isUpdating,
  });

  ProfileLoaded copyWith({
    User? user,
    List<GameHistory>? history,
    bool? isHistoryLoading,
    bool? isUpdating,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      history: history ?? this.history,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }
}

class ProfileError extends ProfileState {
  final String message;
  final ProfileState? previousState;

  const ProfileError({
    required this.message,
    this.previousState,
  });
}
