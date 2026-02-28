import 'package:flutter/material.dart';

import '../../core/network/interceptors/error_interceptor.dart';
import '../../core/theme/colors.dart';
import 'themed_icon_button.dart';

/// Виджет отображения ошибки
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message, super.key,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Повторить',
  });

  /// Создать из ApiError
  factory ErrorView.fromApiError({
    required ApiError error,
    VoidCallback? onRetry,
  }) =>
      ErrorView(
        message: error.message,
        icon: _iconForCode(error.code),
        onRetry: onRetry,
      );

  /// Сообщение об ошибке
  final String message;

  /// Иконка (по умолчанию - warning)
  final IconData? icon;

  /// Callback для повторной попытки
  final VoidCallback? onRetry;

  /// Текст кнопки повтора
  final String retryLabel;

  static IconData _iconForCode(String code) => switch (code) {
        'no_internet' || 'connection_error' => Icons.wifi_off_rounded,
        'timeout' => Icons.timer_off_rounded,
        'unauthorized' => Icons.lock_outline_rounded,
        'not_found' => Icons.search_off_rounded,
        'server_error' => Icons.cloud_off_rounded,
        _ => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon ?? Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Компактная версия для inline-отображения
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    required this.message, super.key,
    this.onRetry,
    this.onDismiss,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onErrorContainer,
                    ),
              ),
            ),
            if (onRetry != null)
              ThemedIconButton(
                icon: Icons.refresh,
                onPressed: onRetry,
                tooltip: 'Повторить',
                iconColor: AppColors.onErrorContainer,
                backgroundColor: AppColors.error.withValues(alpha: 0.2),
              ),
            if (onDismiss != null)
              ThemedIconButton(
                icon: Icons.close,
                onPressed: onDismiss,
                tooltip: 'Закрыть',
                iconColor: AppColors.onErrorContainer,
                backgroundColor: AppColors.error.withValues(alpha: 0.2),
              ),
          ],
        ),
      );
}
