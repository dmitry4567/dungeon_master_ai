import 'package:freezed_annotation/freezed_annotation.dart';

part 'tts_state.freezed.dart';

enum TTSStatus {
  /// Nothing is playing
  idle,

  /// Loading/buffering audio
  loading,

  /// Audio is playing
  playing,

  /// Audio is paused (e.g., by interruption)
  paused,

  /// An error occurred during playback
  error,
}

@freezed
class TTSState with _$TTSState {
  const factory TTSState({
    /// The current playback status
    @Default(TTSStatus.idle) TTSStatus status,

    /// The ID of the message currently being played
    String? currentMessageId,

    /// The error message if status is [TTSStatus.error]
    String? errorMessage,
    
    /// Flag to indicate if audio was playing before an interruption
    @Default(false) bool wasPlayingBeforeInterruption,
  }) = _TTSState;
}
