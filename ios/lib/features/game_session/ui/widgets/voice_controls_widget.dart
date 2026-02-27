import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/voice_cubit.dart';
import '../../models/voice_models.dart';
import 'voice_participant_indicator.dart';

/// Widget for voice channel controls
class VoiceControlsWidget extends StatelessWidget {
  const VoiceControlsWidget({
    super.key,
    required this.roomId,
    required this.isRoomActive,
  });

  final String roomId;
  final bool isRoomActive;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceCubit, VoiceState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: state.connectionStatus == VoiceConnectionStatus.connected
                  ? const Color(0xFF52B788).withValues(alpha: 0.3)
                  : const Color(0xFF2A2A4E),
            ),
          ),
          child: Row(
            children: [
              _buildConnectionButton(context, state),
              if (state.connectionStatus == VoiceConnectionStatus.connected) ...[
                const SizedBox(width: 8),
                _buildMuteButton(context, state),
                const SizedBox(width: 8),
                Expanded(child: _buildParticipantsList(context, state)),
              ] else
                const Spacer(),
              if (state.errorMessage != null) ...[
                const SizedBox(width: 8),
                _buildErrorIndicator(context, state),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticipantsList(BuildContext context, VoiceState state) {
    final participants = state.participants.values.toList();

    if (participants.isEmpty) {
      return const Text(
        'Ожидание участников...',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: participants.map((p) => _buildParticipantChip(context, p)).toList(),
      ),
    );
  }

  Widget _buildParticipantChip(BuildContext context, VoiceParticipant participant) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: participant.isSpeaking
            ? const Color(0xFF52B788).withValues(alpha: 0.2)
            : const Color(0xFF2A2A4E),
        borderRadius: BorderRadius.circular(16),
        border: participant.isSpeaking
            ? Border.all(color: const Color(0xFF52B788), width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (participant.isSpeaking)
            const VoiceParticipantIndicator(isSpeaking: true, size: 16)
          else if (participant.isMuted)
            const MutedIndicator(size: 14)
          else
            Icon(
              Icons.person,
              size: 14,
              color: participant.isConnected ? Colors.white54 : Colors.white24,
            ),
          const SizedBox(width: 4),
          Text(
            participant.displayName,
            style: TextStyle(
              color: participant.isSpeaking ? const Color(0xFF52B788) : Colors.white70,
              fontSize: 12,
              fontWeight: participant.isSpeaking ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionButton(BuildContext context, VoiceState state) {
    final cubit = context.read<VoiceCubit>();

    switch (state.connectionStatus) {
      case VoiceConnectionStatus.disconnected:
        return _VoiceButton(
          onPressed: isRoomActive ? () => cubit.connect(roomId) : null,
          icon: Icons.headset_off,
          label: 'Join Voice',
          color: isRoomActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          tooltip: isRoomActive ? 'Join voice channel' : 'Voice available only in active games',
        );

      case VoiceConnectionStatus.connecting:
      case VoiceConnectionStatus.reconnecting:
        return _VoiceButton(
          onPressed: null,
          icon: Icons.sync,
          label: state.connectionStatus == VoiceConnectionStatus.reconnecting
              ? 'Reconnecting...'
              : 'Connecting...',
          color: Theme.of(context).colorScheme.secondary,
          isLoading: true,
        );

      case VoiceConnectionStatus.connected:
        return _VoiceButton(
          onPressed: () => cubit.disconnect(),
          icon: Icons.headset,
          label: 'Leave Voice',
          color: Theme.of(context).colorScheme.tertiary,
          tooltip: 'Leave voice channel',
        );

      case VoiceConnectionStatus.error:
        // Check if error is about microphone permission
        final isPermissionError = state.errorMessage?.contains('настройки') == true ||
            state.errorMessage?.contains('микрофону') == true;

        if (isPermissionError) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VoiceButton(
                onPressed: () => cubit.openSettings(),
                icon: Icons.settings,
                label: 'Настройки',
                color: Theme.of(context).colorScheme.error,
                tooltip: 'Открыть настройки приложения',
              ),
              const SizedBox(width: 8),
              _VoiceButton(
                onPressed: () => cubit.connect(roomId),
                icon: Icons.refresh,
                label: 'Повторить',
                color: Theme.of(context).colorScheme.secondary,
                tooltip: 'Попробовать снова',
              ),
            ],
          );
        }

        return _VoiceButton(
          onPressed: () => cubit.connect(roomId),
          icon: Icons.refresh,
          label: 'Повторить',
          color: Theme.of(context).colorScheme.error,
          tooltip: 'Переподключиться к голосовому каналу',
        );
    }
  }

  Widget _buildMuteButton(BuildContext context, VoiceState state) {
    final cubit = context.read<VoiceCubit>();

    return IconButton(
      onPressed: () => cubit.toggleMute(),
      icon: Icon(
        state.isMuted ? Icons.mic_off : Icons.mic,
        color: state.isMuted
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      tooltip: state.isMuted ? 'Unmute' : 'Mute',
      style: IconButton.styleFrom(
        backgroundColor: state.isMuted
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  Widget _buildErrorIndicator(BuildContext context, VoiceState state) {
    return Tooltip(
      message: state.errorMessage ?? 'Unknown error',
      child: Icon(
        Icons.warning_amber_rounded,
        color: Theme.of(context).colorScheme.error,
        size: 20,
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(icon, color: color, size: 18),
      label: Text(
        label,
        style: TextStyle(color: color),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
