import 'package:flutter/material.dart';

/// Animated indicator showing when a participant is speaking
class VoiceParticipantIndicator extends StatefulWidget {
  const VoiceParticipantIndicator({
    super.key,
    required this.isSpeaking,
    this.size = 24.0,
  });

  final bool isSpeaking;
  final double size;

  @override
  State<VoiceParticipantIndicator> createState() =>
      _VoiceParticipantIndicatorState();
}

class _VoiceParticipantIndicatorState extends State<VoiceParticipantIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isSpeaking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceParticipantIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF52B788).withValues(alpha: 0.3),
              border: Border.all(
                color: const Color(0xFF52B788),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.mic,
              size: widget.size * 0.6,
              color: const Color(0xFF52B788),
            ),
          ),
        ),
      ),
    );
  }
}

/// Speaking border indicator that wraps around an avatar or name
class SpeakingBorderIndicator extends StatefulWidget {
  const SpeakingBorderIndicator({
    super.key,
    required this.isSpeaking,
    required this.child,
    this.borderRadius = 8.0,
  });

  final bool isSpeaking;
  final Widget child;
  final double borderRadius;

  @override
  State<SpeakingBorderIndicator> createState() =>
      _SpeakingBorderIndicatorState();
}

class _SpeakingBorderIndicatorState extends State<SpeakingBorderIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isSpeaking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SpeakingBorderIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.isSpeaking
              ? Border.all(
                  color: Color.lerp(
                    const Color(0xFF52B788).withValues(alpha: 0.3),
                    const Color(0xFF52B788),
                    _pulseAnimation.value,
                  )!,
                  width: 2,
                )
              : null,
          boxShadow: widget.isSpeaking
              ? [
                  BoxShadow(
                    color: const Color(0xFF52B788)
                        .withValues(alpha: 0.3 * _pulseAnimation.value),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Muted indicator icon
class MutedIndicator extends StatelessWidget {
  const MutedIndicator({
    super.key,
    this.size = 16.0,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE76F51).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.mic_off,
        size: size,
        color: const Color(0xFFE76F51),
      ),
    );
  }
}
