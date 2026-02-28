import 'dart:async';

import 'package:ai_dungeon_master/features/game_session/bloc/tts_cubit.dart';
import 'package:ai_dungeon_master/features/game_session/bloc/tts_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TTSButton extends StatefulWidget {
  final String messageId;
  final String text;

  const TTSButton({
    super.key,
    required this.messageId,
    required this.text,
  });

  @override
  State<TTSButton> createState() => _TTSButtonState();
}

class _TTSButtonState extends State<TTSButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPressed(BuildContext context, bool isPlaying) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (isPlaying) {
        context.read<TTSCubit>().stopPlayback();
      } else {
        context.read<TTSCubit>().playMessage(widget.messageId, widget.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<TTSCubit, TTSState>(
        listener: (context, state) {
          final isPlaying = state.status == TTSStatus.playing &&
              state.currentMessageId == widget.messageId;
          if (isPlaying) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
        },
        builder: (context, state) {
          final isCurrentMessage = state.currentMessageId == widget.messageId;
          final isLoading =
              isCurrentMessage && state.status == TTSStatus.loading;
          final isPlaying =
              isCurrentMessage && state.status == TTSStatus.playing;
          final isError = isCurrentMessage && state.status == TTSStatus.error;

          Widget icon;
          if (isLoading) {
            icon = const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            );
          } else if (isError) {
            icon = Tooltip(
              message: state.errorMessage ?? 'An unknown error occurred',
              child: const Icon(Icons.error_outline, color: Colors.red),
            );
          } else {
            icon = Icon(
              isPlaying ? Icons.stop : Icons.multitrack_audio_rounded,
            );
          }

          return IconButton(
            onPressed: () => _onPressed(context, isPlaying),
            icon: icon,
          );
        },
      );
}
