import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_event.freezed.dart';

/// События ProfileBloc
@freezed
class ProfileEvent with _$ProfileEvent {
  const factory ProfileEvent.loadProfile() = LoadProfileEvent;
  const factory ProfileEvent.loadHistory() = LoadHistoryEvent;
  const factory ProfileEvent.updateName(String name) = UpdateNameEvent;
  const factory ProfileEvent.updateAvatar(String avatarUrl) = UpdateAvatarEvent;
  const factory ProfileEvent.clearError() = ClearErrorEvent;
}
