import 'package:freezed_annotation/freezed_annotation.dart';

import '../../auth/models/user.dart';
import '../models/game_history.dart';

part 'profile_state.freezed.dart';

/// Состояния ProfileBloc
@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = ProfileInitial;
  const factory ProfileState.loading() = ProfileLoading;
  const factory ProfileState.loaded({
    required User user,
    required List<GameHistory> history,
    required bool isHistoryLoading,
    required bool isUpdating,
  }) = ProfileLoaded;
  const factory ProfileState.error({
    required String message,
    ProfileState? previousState,
  }) = ProfileError;
}
