import 'package:flutter/material.dart';

import 'colors.dart';

/// Типографика приложения с поддержкой Dynamic Type
abstract final class AppTypography {
  /// Базовый стиль текста
  static const _baseStyle = TextStyle(
    fontFamily: '.SF Pro Text',
    color: AppColors.onBackground,
    letterSpacing: 0,
  );

  /// Display Large - Заголовки экранов
  static final displayLarge = _baseStyle.copyWith(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    height: 1.12,
    letterSpacing: -0.25,
  );

  /// Display Medium
  static final displayMedium = _baseStyle.copyWith(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    height: 1.16,
  );

  /// Display Small
  static final displaySmall = _baseStyle.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.22,
  );

  /// Headline Large - Заголовки секций
  static final headlineLarge = _baseStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// Headline Medium
  static final headlineMedium = _baseStyle.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.29,
  );

  /// Headline Small
  static final headlineSmall = _baseStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,
  );

  /// Title Large - Названия карточек
  static final titleLarge = _baseStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.27,
  );

  /// Title Medium
  static final titleMedium = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.15,
  );

  /// Title Small
  static final titleSmall = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
    letterSpacing: 0.1,
  );

  /// Body Large - Основной текст
  static final bodyLarge = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.5,
  );

  /// Body Medium
  static final bodyMedium = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0.25,
  );

  /// Body Small
  static final bodySmall = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.4,
  );

  /// Label Large - Кнопки
  static final labelLarge = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
    letterSpacing: 0.1,
  );

  /// Label Medium
  static final labelMedium = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,
    letterSpacing: 0.5,
  );

  /// Label Small
  static final labelSmall = _baseStyle.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0.5,
  );

  /// TextTheme для Material
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
