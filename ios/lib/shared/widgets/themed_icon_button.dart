import 'package:flutter/material.dart';

/// Themed IconButton with consistent style across the app
/// Matches the back button style from game session screen
class ThemedIconButton extends StatelessWidget {
  const ThemedIconButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = const Color(0xFFD4AF37),
    this.backgroundColor = const Color(0xFF1A1A2E),
    this.iconSize = 18,
    this.padding = 8,
    this.borderRadius = 8,
    this.tooltip,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color iconColor;
  final Color backgroundColor;
  final double iconSize;
  final double padding;
  final double borderRadius;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: enabled
                ? backgroundColor
                : backgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            icon,
            color: enabled ? iconColor : iconColor.withValues(alpha: 0.5),
            size: iconSize,
          ),
        ),
      );
}
