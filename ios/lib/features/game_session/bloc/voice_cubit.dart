import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/game_session_repository.dart';
import '../models/voice_models.dart';

/// Voice channel state
class VoiceState {
  final VoiceConnectionStatus connectionStatus;
  final bool isMuted;
  final Map<int, VoiceParticipant> participants;
  final VoiceToken? token;
  final String? errorMessage;
  final String? roomId;

  const VoiceState({
    this.connectionStatus = VoiceConnectionStatus.disconnected,
    this.isMuted = false,
    this.participants = const {},
    this.token,
    this.errorMessage,
    this.roomId,
  });

  VoiceState copyWith({
    VoiceConnectionStatus? connectionStatus,
    bool? isMuted,
    Map<int, VoiceParticipant>? participants,
    VoiceToken? token,
    String? errorMessage,
    String? roomId,
  }) {
    return VoiceState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isMuted: isMuted ?? this.isMuted,
      participants: participants ?? this.participants,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
      roomId: roomId ?? this.roomId,
    );
  }
}

/// Cubit for managing Agora voice channel
class VoiceCubit extends Cubit<VoiceState> {
  VoiceCubit({
    required GameSessionRepository repository,
  })  : _repository = repository,
        super(const VoiceState());

  final GameSessionRepository _repository;
  RtcEngine? _engine;
  bool _isEngineInitialized = false;

  /// Connect to voice channel for a room
  Future<void> connect(String roomId) async {
    if (state.connectionStatus == VoiceConnectionStatus.connected ||
        state.connectionStatus == VoiceConnectionStatus.connecting) {
      return;
    }

    emit(state.copyWith(
      connectionStatus: VoiceConnectionStatus.connecting,
      errorMessage: null,
      roomId: roomId,
    ),);

    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        final isPermanentlyDenied = micPermission.isPermanentlyDenied;
        emit(state.copyWith(
          connectionStatus: VoiceConnectionStatus.error,
          errorMessage: isPermanentlyDenied
              ? 'Доступ к микрофону запрещён. Откройте настройки, чтобы разрешить доступ.'
              : 'Для голосового чата необходим доступ к микрофону',
        ),);
        return;
      }

      // Get voice token from backend
      final token = await _repository.getVoiceToken(roomId);
      emit(state.copyWith(token: token));

      // Initialize Agora engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: token.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),);

      _isEngineInitialized = true;

      // Set client role to broadcaster (can send and receive audio)
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Enable audio
      await _engine!.enableAudio();

      // Enable audio volume indication for speaking detection
      await _engine!.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );

      // Register event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: _onJoinChannelSuccess,
        onLeaveChannel: _onLeaveChannel,
        onUserJoined: _onUserJoined,
        onUserOffline: _onUserOffline,
        onAudioVolumeIndication: _onAudioVolumeIndication,
        onActiveSpeaker: _onActiveSpeaker,
        onConnectionStateChanged: _onConnectionStateChanged,
        onTokenPrivilegeWillExpire: _onTokenPrivilegeWillExpire,
        onError: _onError,
      ),);

      // Join channel
      await _engine!.joinChannel(
        token: token.token,
        channelId: token.channelName,
        uid: token.uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      emit(state.copyWith(
        connectionStatus: VoiceConnectionStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  /// Disconnect from voice channel
  Future<void> disconnect() async {
    if (_engine != null && _isEngineInitialized) {
      try {
        await _engine!.leaveChannel();
        await _engine!.release();
      } catch (_) {
        // Ignore errors during cleanup
      }
      _engine = null;
      _isEngineInitialized = false;
    }

    emit(const VoiceState());
  }

  /// Open app settings (for granting microphone permission)
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Toggle local microphone mute
  Future<void> toggleMute() async {
    if (_engine == null || !_isEngineInitialized) return;

    final newMuteState = !state.isMuted;
    await _engine!.muteLocalAudioStream(newMuteState);
    emit(state.copyWith(isMuted: newMuteState));
  }

  // Event handlers

  void _onJoinChannelSuccess(RtcConnection connection, int elapsed) {
    emit(state.copyWith(connectionStatus: VoiceConnectionStatus.connected));
  }

  void _onLeaveChannel(RtcConnection connection, RtcStats stats) {
    emit(state.copyWith(
      connectionStatus: VoiceConnectionStatus.disconnected,
      participants: {},
    ),);
  }

  void _onUserJoined(RtcConnection connection, int remoteUid, int elapsed) {
    final participants = Map<int, VoiceParticipant>.from(state.participants);
    participants[remoteUid] = VoiceParticipant(
      uid: remoteUid,
      userId: '',
      displayName: 'Player $remoteUid',
      isConnected: true,
    );
    emit(state.copyWith(participants: participants));
  }

  void _onUserOffline(
    RtcConnection connection,
    int remoteUid,
    UserOfflineReasonType reason,
  ) {
    final participants = Map<int, VoiceParticipant>.from(state.participants);
    participants.remove(remoteUid);
    emit(state.copyWith(participants: participants));
  }

  void _onAudioVolumeIndication(
    RtcConnection connection,
    List<AudioVolumeInfo> speakers,
    int speakerNumber,
    int totalVolume,
  ) {
    final participants = Map<int, VoiceParticipant>.from(state.participants);
    var hasChanges = false;

    // Reset all speaking states first
    for (final entry in participants.entries) {
      if (entry.value.isSpeaking) {
        participants[entry.key] = entry.value.copyWith(isSpeaking: false);
        hasChanges = true;
      }
    }

    // Set speaking state for active speakers (volume > 30)
    for (final speaker in speakers) {
      if (speaker.volume != null && speaker.volume! > 30) {
        final uid = speaker.uid ?? 0;
        if (uid != 0 && participants.containsKey(uid)) {
          participants[uid] = participants[uid]!.copyWith(isSpeaking: true);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      emit(state.copyWith(participants: participants));
    }
  }

  void _onActiveSpeaker(RtcConnection connection, int uid) {
    // Backup speaker detection - used when volume indication is not reliable
    if (uid != 0 && state.participants.containsKey(uid)) {
      final participants = Map<int, VoiceParticipant>.from(state.participants);

      // Reset all speaking states
      for (final entry in participants.entries) {
        participants[entry.key] = entry.value.copyWith(isSpeaking: false);
      }

      // Set active speaker
      participants[uid] = participants[uid]!.copyWith(isSpeaking: true);
      emit(state.copyWith(participants: participants));
    }
  }

  void _onConnectionStateChanged(
    RtcConnection connection,
    ConnectionStateType state_,
    ConnectionChangedReasonType reason,
  ) {
    switch (state_) {
      case ConnectionStateType.connectionStateConnecting:
        emit(state.copyWith(connectionStatus: VoiceConnectionStatus.connecting));
      case ConnectionStateType.connectionStateConnected:
        emit(state.copyWith(connectionStatus: VoiceConnectionStatus.connected));
      case ConnectionStateType.connectionStateReconnecting:
        emit(state.copyWith(connectionStatus: VoiceConnectionStatus.reconnecting));
      case ConnectionStateType.connectionStateDisconnected:
      case ConnectionStateType.connectionStateFailed:
        emit(state.copyWith(connectionStatus: VoiceConnectionStatus.disconnected));
    }
  }

  Future<void> _onTokenPrivilegeWillExpire(
    RtcConnection connection,
    String token,
  ) async {
    // Token is about to expire, request a new one
    if (state.roomId != null && _engine != null) {
      try {
        final newToken = await _repository.getVoiceToken(state.roomId!);
        await _engine!.renewToken(newToken.token);
        emit(state.copyWith(token: newToken));
      } catch (e) {
        // Token renewal failed, connection will drop
        emit(state.copyWith(
          errorMessage: 'Failed to renew voice token: $e',
        ),);
      }
    }
  }

  void _onError(ErrorCodeType err, String msg) {
    emit(state.copyWith(
      connectionStatus: VoiceConnectionStatus.error,
      errorMessage: 'Agora error: $msg (code: ${err.name})',
    ),);
  }

  @override
  Future<void> close() async {
    await disconnect();
    return super.close();
  }
}
