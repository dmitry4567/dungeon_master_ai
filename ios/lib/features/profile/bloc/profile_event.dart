/// События ProfileBloc
abstract class ProfileEvent {
  const ProfileEvent();
}

class LoadProfileEvent extends ProfileEvent {
  const LoadProfileEvent();
}

class LoadHistoryEvent extends ProfileEvent {
  const LoadHistoryEvent();
}

class UpdateNameEvent extends ProfileEvent {
  final String name;

  const UpdateNameEvent(this.name);
}

class UpdateAvatarEvent extends ProfileEvent {
  final String avatarUrl;

  const UpdateAvatarEvent(this.avatarUrl);
}

class ClearErrorEvent extends ProfileEvent {
  const ClearErrorEvent();
}
