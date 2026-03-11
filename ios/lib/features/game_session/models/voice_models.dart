/// Voice channel connection status
enum VoiceConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Agora voice token received from backend
class VoiceToken {
  final String token;
  final String channelName;
  final int uid;
  final String appId;
  final DateTime expiresAt;

  const VoiceToken({
    required this.token,
    required this.channelName,
    required this.uid,
    required this.appId,
    required this.expiresAt,
  });

  factory VoiceToken.fromJson(Map<String, dynamic> json) {
    return VoiceToken(
      token: json['token'] as String,
      channelName: json['channel_name'] as String,
      uid: (json['uid'] as num).toInt(),
      appId: json['app_id'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'channel_name': channelName,
      'uid': uid,
      'app_id': appId,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}

/// Voice participant in the channel
class VoiceParticipant {
  final int uid;
  final String userId;
  final String displayName;
  final bool isSpeaking;
  final bool isMuted;
  final bool isConnected;

  const VoiceParticipant({
    required this.uid,
    required this.userId,
    required this.displayName,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isConnected = false,
  });

  factory VoiceParticipant.fromJson(Map<String, dynamic> json) {
    return VoiceParticipant(
      uid: (json['uid'] as num).toInt(),
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      isSpeaking: json['is_speaking'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      isConnected: json['is_connected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'user_id': userId,
      'display_name': displayName,
      'is_speaking': isSpeaking,
      'is_muted': isMuted,
      'is_connected': isConnected,
    };
  }

  VoiceParticipant copyWith({
    int? uid,
    String? userId,
    String? displayName,
    bool? isSpeaking,
    bool? isMuted,
    bool? isConnected,
  }) {
    return VoiceParticipant(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
