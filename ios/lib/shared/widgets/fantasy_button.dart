import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Кнопка в фэнтези-стиле
class FantasyButton extends StatefulWidget {
  const FantasyButton({
    required this.label, required this.onPressed, super.key,
    this.icon,
    this.variant = FantasyButtonVariant.primary,
    this.size = FantasyButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
  });

  /// Текст кнопки
  final String label;

  /// Callback при нажатии
  final VoidCallback? onPressed;

  /// Иконка слева
  final IconData? icon;

  /// Вариант стиля
  final FantasyButtonVariant variant;

  /// Размер кнопки
  final FantasyButtonSize size;

  /// Состояние загрузки
  final bool isLoading;

  /// Отключена ли кнопка
  final bool isDisabled;

  /// Фиксированная ширина
  final double? width;

  @override
  State<FantasyButton> createState() => _FantasyButtonState();
}

class _FantasyButtonState extends State<FantasyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  bool get _isEnabled =>
      !widget.isLoading && !widget.isDisabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();
    final padding = _getPadding();
    final textStyle = _getTextStyle();

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _isEnabled ? widget.onPressed : null,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            padding: padding,
            decoration: BoxDecoration(
              gradient: widget.variant == FantasyButtonVariant.primary &&
                      _isEnabled
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.background,
                        colors.background.withValues(alpha: 0.8),
                      ],
                    )
                  : null,
              color: widget.variant != FantasyButtonVariant.primary
                  ? colors.background
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.border,
                width: 2,
              ),
              boxShadow: _isEnabled && !_isPressed
                  ? [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize:
                  widget.width != null ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: _getIconSize(),
                    height: _getIconSize(),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.foreground,
                    ),
                  )
                else if (widget.icon != null)
                  Icon(
                    widget.icon,
                    size: _getIconSize(),
                    color: colors.foreground,
                  ),
                if ((widget.icon != null || widget.isLoading) &&
                    widget.label.isNotEmpty)
                  const SizedBox(width: 8),
                if (widget.label.isNotEmpty)
                  Text(
                    widget.label,
                    style: textStyle.copyWith(color: colors.foreground),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ButtonColors _getColors() {
    if (!_isEnabled) {
      return const _ButtonColors(
        background: AppColors.surfaceVariant,
        foreground: AppColors.outline,
        border: AppColors.outline,
        shadow: Colors.transparent,
      );
    }

    return switch (widget.variant) {
      FantasyButtonVariant.primary => _ButtonColors(
          background: AppColors.primary,
          foreground: AppColors.onPrimary,
          border: AppColors.primaryLight,
          shadow: AppColors.primary.withValues(alpha: 0.4),
        ),
      FantasyButtonVariant.secondary => _ButtonColors(
          background: AppColors.secondary,
          foreground: AppColors.onSecondary,
          border: AppColors.secondaryLight,
          shadow: AppColors.secondary.withValues(alpha: 0.4),
        ),
      FantasyButtonVariant.outline => const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.primary,
          border: AppColors.primary,
          shadow: Colors.transparent,
        ),
      FantasyButtonVariant.ghost => const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.primary,
          border: Colors.transparent,
          shadow: Colors.transparent,
        ),
      FantasyButtonVariant.danger => _ButtonColors(
          background: AppColors.error,
          foreground: AppColors.onError,
          border: AppColors.error,
          shadow: AppColors.error.withValues(alpha: 0.4),
        ),
    };
  }

  EdgeInsets _getPadding() => switch (widget.size) {
        FantasyButtonSize.small =>
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        FantasyButtonSize.medium =>
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        FantasyButtonSize.large =>
          const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      };

  TextStyle _getTextStyle() => switch (widget.size) {
        FantasyButtonSize.small => AppTypography.labelMedium,
        FantasyButtonSize.medium => AppTypography.labelLarge,
        FantasyButtonSize.large =>
          AppTypography.labelLarge.copyWith(fontSize: 16),
      };

  double _getIconSize() => switch (widget.size) {
        FantasyButtonSize.small => 16,
        FantasyButtonSize.medium => 20,
        FantasyButtonSize.large => 24,
      };
}

/// Варианты стиля кнопки
enum FantasyButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  danger,
}

/// Размеры кнопки
enum FantasyButtonSize {
  small,
  medium,
  large,
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color shadow;
}
