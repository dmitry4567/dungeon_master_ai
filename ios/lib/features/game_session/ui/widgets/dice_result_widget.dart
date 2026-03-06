import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../models/dice_result.dart';

/// Распарсенный результат броска из текста сообщения
class ParsedDiceRoll {
  const ParsedDiceRoll({
    required this.diceType,
    required this.roll,
    this.modifier,
    this.total,
    this.dc,
    this.success,
  });

  final String diceType; // D20, d6, etc.
  final int roll; // базовый результат броска
  final int? modifier;
  final int? total;
  final int? dc;
  final bool? success;

  /// Парсит текст формата: "🎲 Бросок D20: 15 + 3 = 18 (DC 15) ✓ Успех!"
  static ParsedDiceRoll? tryParse(String content) {
    if (!content.contains('🎲')) return null;

    // Парсим тип кубика: D20, d6, 2d6, etc.
    final diceRegex = RegExp(r'🎲\s*Бросок\s+(\d*[dD]\d+):', caseSensitive: false);
    final diceMatch = diceRegex.firstMatch(content);
    if (diceMatch == null) return null;

    final diceType = diceMatch.group(1)!;

    // Парсим базовый бросок: "D20: 15"
    final rollRegex = RegExp(r':\s*(\d+)');
    final rollMatch = rollRegex.firstMatch(content);
    if (rollMatch == null) return null;
    final roll = int.tryParse(rollMatch.group(1)!);
    if (roll == null) return null;

    // Парсим модификатор: "+ 3" или "- 2"
    final modifierRegex = RegExp(r'[+\-]\s*(\d+)');
    final modifierMatch = modifierRegex.firstMatch(content);
    int? modifier;
    if (modifierMatch != null) {
      final modValue = int.tryParse(modifierMatch.group(1)!);
      if (modValue != null) {
        modifier = modValue * (modifierMatch.group(0)!.contains('-') ? -1 : 1);
      }
    }

    // Парсим итого: "= 18"
    final totalRegex = RegExp(r'=\s*(\d+)');
    final totalMatch = totalRegex.firstMatch(content);
    final total = totalMatch != null ? int.tryParse(totalMatch.group(1)!) : null;

    // Парсим DC: "(DC 15)"
    final dcRegex = RegExp(r'DC\s*(\d+)', caseSensitive: false);
    final dcMatch = dcRegex.firstMatch(content);
    final dc = dcMatch != null ? int.tryParse(dcMatch.group(1)!) : null;

    // Определяем успех/провал
    bool? success;
    if (content.contains('✓') || content.toLowerCase().contains('успех')) {
      success = true;
    } else if (content.contains('✗') || content.toLowerCase().contains('провал')) {
      success = false;
    }

    return ParsedDiceRoll(
      diceType: diceType,
      roll: roll,
      modifier: modifier,
      total: total,
      dc: dc,
      success: success,
    );
  }
}

/// Анимированный виджет отображения результата броска кубика
class AnimatedDiceResultWidget extends StatefulWidget {
  const AnimatedDiceResultWidget({
    required this.result,
    super.key,
  });

  final ParsedDiceRoll result;

  @override
  State<AnimatedDiceResultWidget> createState() =>
      _AnimatedDiceResultWidgetState();
}

class _AnimatedDiceResultWidgetState extends State<AnimatedDiceResultWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_controller);

    // Небольшое покачивание туда-обратно
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0.1),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: -0.1),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.1, end: 0.05),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: 0),
        weight: 25,
      ),
    ]).animate(_controller);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 0.3)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.result.success;
    final hasOutcome = isSuccess != null;

    final borderColor = !hasOutcome
        ? AppColors.secondary
        : isSuccess
            ? AppColors.success
            : AppColors.error;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor.withValues(alpha: _glowAnimation.value),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withValues(alpha: _glowAnimation.value * 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Иконка кубика с результатом
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.result.diceType.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.secondary.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.result.roll}',
                          style: TextStyle(
                            color: borderColor,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Формула расчета
                  if (widget.result.modifier != null ||
                      widget.result.total != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.result.roll}',
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.result.modifier != null) ...[
                            Text(
                              widget.result.modifier! > 0
                                  ? ' + ${widget.result.modifier}'
                                  : ' - ${widget.result.modifier!.abs()}',
                              style: TextStyle(
                                color: AppColors.onSurface.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                          if (widget.result.total != null) ...[
                            Text(
                              ' = ',
                              style: TextStyle(
                                color: AppColors.onSurface.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${widget.result.total}',
                              style: TextStyle(
                                color: borderColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // DC и результат
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.result.dc != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'DC ${widget.result.dc}',
                            style: TextStyle(
                              color: AppColors.onSurface.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (widget.result.dc != null && hasOutcome)
                        const SizedBox(width: 12),
                      if (hasOutcome)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? AppColors.success.withValues(alpha: 0.2)
                                : AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSuccess
                                  ? AppColors.success.withValues(alpha: 0.5)
                                  : AppColors.error.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isSuccess ? '✓' : '✗',
                                style: TextStyle(
                                  color: isSuccess
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSuccess ? 'Успех' : 'Провал',
                                style: TextStyle(
                                  color: isSuccess
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Виджет отображения результата броска кубиков (старый, для совместимости)
class DiceResultWidget extends StatelessWidget {
  const DiceResultWidget({required this.result, super.key});

  final DiceResult result;

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.success;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess == null
              ? AppColors.secondary
              : isSuccess
                  ? AppColors.success
                  : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Иконка кубика
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                result.type,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Детали броска
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Бросок + модификатор = итого
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (result.baseRoll != null)
                      Text(
                        '${result.baseRoll}',
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    if (result.modifier != null && result.modifier != 0)
                      Text(
                        result.modifier! > 0
                            ? ' + ${result.modifier}'
                            : ' - ${result.modifier!.abs()}',
                        style: TextStyle(
                          color: AppColors.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    if (result.total != null) ...[
                      Text(
                        ' = ',
                        style: TextStyle(
                          color: AppColors.onSurface.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${result.total}',
                        style: TextStyle(
                          color: isSuccess == null
                              ? AppColors.secondary
                              : isSuccess
                                  ? AppColors.success
                                  : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                // DC и навык
                if (result.dc != null || result.skill != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (result.dc != null)
                        Text(
                          'DC ${result.dc}',
                          style: TextStyle(
                            color: AppColors.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      if (result.dc != null && result.skill != null)
                        const SizedBox(width: 8),
                      if (result.skill != null)
                        Text(
                          result.skill!,
                          style: const TextStyle(
                            color: AppColors.secondaryLight,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          // Результат успех/провал
          if (isSuccess != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSuccess
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSuccess ? 'Успех' : 'Провал',
                style: TextStyle(
                  color: isSuccess ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
