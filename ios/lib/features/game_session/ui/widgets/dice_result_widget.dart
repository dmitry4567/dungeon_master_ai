import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../models/dice_result.dart';

/// Виджет отображения результата броска кубиков
class DiceResultWidget extends StatelessWidget {
  const DiceResultWidget({super.key, required this.result});

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
            width: 40,
            height: 40,
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
