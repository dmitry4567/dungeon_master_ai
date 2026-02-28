import 'dart:async';
import 'dart:typed_data';

import 'package:ai_dungeon_master/features/game_session/data/tts_api.dart';
import 'package:audio_session/audio_session.dart';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';

import 'tts_state.dart';

// Audio source from buffered bytes
class BufferedAudioSource extends StreamAudioSource {
  final Uint8List bytes;

  BufferedAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;

    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

@injectable
class TTSCubit extends Cubit<TTSState> {
  final AudioPlayer _audioPlayer;
  final TTSApi _ttsApi;
  StreamSubscription? _interruptionSubscription;

  TTSCubit(this._audioPlayer, this._ttsApi) : super(const TTSState()) {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _interruptionSubscription = session.interruptionEventStream.listen((event) {
      if (isClosed) return;

      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_audioPlayer.playing) {
              _audioPlayer.pause();
              if (!isClosed) {
                emit(state.copyWith(wasPlayingBeforeInterruption: true));
              }
            }
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (state.wasPlayingBeforeInterruption) {
              _audioPlayer.play();
              if (!isClosed) {
                emit(state.copyWith(wasPlayingBeforeInterruption: false));
              }
            }
            break;
        }
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      if (isClosed) return;

      if (playerState.processingState == ProcessingState.completed) {
        if (!isClosed) {
          emit(state.copyWith(status: TTSStatus.idle, currentMessageId: null));
        }
      }
    });
  }

  Future<void> playMessage(String messageId, String text) async {
    if (isClosed) return;

    if (text.trim().length < 10) {
      print('[TTS] Text too short, skipping TTS');
      return;
    }

    if (state.status == TTSStatus.playing && state.currentMessageId == messageId) {
      print('[TTS] Already playing this message, stopping');
      return stopPlayback();
    }

    if (_audioPlayer.playing) {
      print('[TTS] Stopping previous playback');
      await stopPlayback();
    }

    print('[TTS] Starting playback for message $messageId');
    if (!isClosed) {
      emit(state.copyWith(status: TTSStatus.loading, currentMessageId: messageId));
    }

    try {
      print('[TTS] Creating audio stream');
      final audioStream = _ttsApi.streamTTS(text, messageId);

      print('[TTS] Buffering audio data...');
      final List<int> audioBytes = [];
      await for (final chunk in audioStream) {
        if (isClosed) {
          print('[TTS] Cubit closed, stopping buffering');
          return;
        }
        audioBytes.addAll(chunk);
      }

      if (isClosed) return;

      print('[TTS] Buffered ${audioBytes.length} bytes of audio data');

      if (audioBytes.isEmpty) {
        print('[TTS] No audio data received from server');
        if (!isClosed) {
          emit(state.copyWith(
            status: TTSStatus.error,
            errorMessage: 'Не удалось получить аудио с сервера',
          ));
        }
        return;
      }

      final audioData = Uint8List.fromList(audioBytes);
      print('[TTS] Setting audio source with buffered data');
      await _audioPlayer.setAudioSource(BufferedAudioSource(audioData));

      if (isClosed) return;

      print('[TTS] Audio source set, starting playback');
      if (!isClosed) {
        emit(state.copyWith(status: TTSStatus.playing, currentMessageId: messageId));
      }
      await _audioPlayer.play();

      print('[TTS] Playback started successfully');
    } on DioException catch (e) {
      if (isClosed) return;

      print('[TTS] DioException: ${e.response?.statusCode} - ${e.message}');
      String errorMessage;
      switch (e.response?.statusCode) {
        case 429:
          errorMessage = 'Превышен лимит прослушиваний, попробуйте позже (через минуту)';
        case 402:
          errorMessage = 'Озвучка временно недоступна';
        default:
          errorMessage = 'Ошибка сети. Пожалуйста, проверьте ваше соединение.';
      }
      if (!isClosed) {
        emit(state.copyWith(status: TTSStatus.error, errorMessage: errorMessage));
      }
    }
    catch (e, stackTrace) {
      if (isClosed) return;

      print('[TTS] Unexpected error: $e');
      print('[TTS] Stack trace: $stackTrace');
      if (!isClosed) {
        emit(state.copyWith(status: TTSStatus.error, errorMessage: 'Произошла неизвестная ошибка: $e'));
      }
    }
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    if (!isClosed) {
      emit(state.copyWith(status: TTSStatus.idle, currentMessageId: null));
    }
  }

  Future<void> checkTtsStatus() async {
    if (isClosed) return;

    try {
      final isAvailable = await _ttsApi.isTtsAvailable();
      if (!isClosed && !isAvailable) {
        emit(state.copyWith(status: TTSStatus.error, errorMessage: 'Озвучка временно недоступна'));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(status: TTSStatus.error, errorMessage: 'Не удалось проверить статус озвучки'));
      }
    }
  }

  void clearState() {
    if (!isClosed) {
      emit(const TTSState());
    }
  }

  @override
  Future<void> close() {
    _interruptionSubscription?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
