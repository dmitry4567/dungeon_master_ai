import 'package:flutter/material.dart';

/// Цветовая палитра приложения в фэнтези-стиле
abstract final class AppColors {
  // Primary - Глубокий пурпурный (магия)
  static const primary = Color(0xFF6B3FA0);
  static const primaryLight = Color(0xFF9B6FD0);
  static const primaryDark = Color(0xFF3D1F72);
  static const onPrimary = Color(0xFFFFFFFF);

  // Secondary - Золотой (сокровища)
  static const secondary = Color(0xFFD4AF37);
  static const secondaryLight = Color(0xFFE8CF7D);
  static const secondaryDark = Color(0xFF8B7620);
  static const onSecondary = Color(0xFF1A1A1A);

  // Tertiary - Изумрудный (природа)
  static const tertiary = Color(0xFF2E8B57);
  static const tertiaryLight = Color(0xFF5EBB87);
  static const tertiaryDark = Color(0xFF1A5B37);
  static const onTertiary = Color(0xFFFFFFFF);

  // Background - Тёмные оттенки пергамента
  static const background = Color(0xFF1A1612);
  static const backgroundLight = Color(0xFF2D2520);
  static const surface = Color(0xFF252018);
  static const surfaceVariant = Color(0xFF3D3428);
  static const onBackground = Color(0xFFF5E6D3);
  static const onSurface = Color(0xFFF5E6D3);

  // Outline и разделители
  static const outline = Color(0xFF5C5040);
  static const outlineVariant = Color(0xFF3D3428);

  // Error - Кровавый красный
  static const error = Color(0xFFCF6679);
  static const errorContainer = Color(0xFF8B0000);
  static const onError = Color(0xFF1A1A1A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // Success - Зелёный здоровья
  static const success = Color(0xFF4CAF50);
  static const onSuccess = Color(0xFFFFFFFF);

  // Warning - Оранжевый предупреждения
  static const warning = Color(0xFFFF9800);
  static const onWarning = Color(0xFF1A1A1A);

  // Info - Синий информации
  static const info = Color(0xFF2196F3);
  static const onInfo = Color(0xFFFFFFFF);

  // Цвета классов D&D
  static const warrior = Color(0xFFC0392B);
  static const mage = Color(0xFF2980B9);
  static const rogue = Color(0xFF27AE60);
  static const cleric = Color(0xFFF39C12);

  // Редкость предметов
  static const common = Color(0xFF9E9E9E);
  static const uncommon = Color(0xFF4CAF50);
  static const rare = Color(0xFF2196F3);
  static const epic = Color(0xFF9C27B0);
  static const legendary = Color(0xFFFF9800);

  // Shadow
  static const shadow = Color(0xFF000000);

  // Прозрачности
  static Color withOpacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}
