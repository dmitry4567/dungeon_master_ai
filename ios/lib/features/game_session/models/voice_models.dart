import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice_models.freezed.dart';
part 'voice_models.g.dart';

/// Voice channel connection status
enum VoiceConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Agora voice token received from backend
@freezed
class VoiceToken with _$VoiceToken {
  const factory VoiceToken({
    required String token,
    @JsonKey(name: 'channel_name') required String channelName,
    required int uid,
    @JsonKey(name: 'app_id') required String appId,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
  }) = _VoiceToken;

  factory VoiceToken.fromJson(Map<String, dynamic> json) =>
      _$VoiceTokenFromJson(json);
}

/// Voice participant in the channel
@freezed
class VoiceParticipant with _$VoiceParticipant {
  const factory VoiceParticipant({
    required int uid,
    required String userId,
    required String displayName,
    @Default(false) bool isSpeaking,
    @Default(false) bool isMuted,
    @Default(false) bool isConnected,
  }) = _VoiceParticipant;

  factory VoiceParticipant.fromJson(Map<String, dynamic> json) =>
      _$VoiceParticipantFromJson(json);
}
