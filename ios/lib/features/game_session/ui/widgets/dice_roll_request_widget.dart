import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../bloc/game_session_bloc.dart';
import '../../bloc/game_session_event.dart';
import '../../models/dice_result.dart';

/// Виджет запроса на бросок кубика
class DiceRollRequestWidget extends StatefulWidget {
  const DiceRollRequestWidget({required this.request, super.key});

  final DiceRequest request;

  @override
  State<DiceRollRequestWidget> createState() => _DiceRollRequestWidgetState();
}

class _DiceRollRequestWidgetState extends State<DiceRollRequestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
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

  void _rollDice() {
    if (_isRolling) return;

    setState(() {
      _isRolling = true;
    });

    _controller.forward().then((_) => _controller.reverse());

    // Генерируем случайные результаты для каждого кубика
    final random = Random();
    final dieSize = _parseDieSize(widget.request.diceType);
    final rolls = List.generate(
      widget.request.numDice,
      (_) => random.nextInt(dieSize) + 1,
    );

    // Отправляем результат
    context.read<GameSessionBloc>().add(
          GameSessionEvent.rollDice(
            requestId: widget.request.requestId,
            rolls: rolls,
          ),
        );
  }

  int _parseDieSize(String diceType) {
    // Парсим d20, d6, d12, etc.
    final match = RegExp(r'd(\d+)').firstMatch(diceType.toLowerCase());
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 20;
    }
    return 20;
  }

  @override
  Widget build(BuildContext context) {
    final dieSize = _parseDieSize(widget.request.diceType);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.9),
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.casino,
                color: AppColors.secondary,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Бросок кубика',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Причина броска
          if (widget.request.reason != null) ...[
            Text(
              widget.request.reason!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface.withValues(alpha: 0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Информация о броске
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(
                  label: 'Тип',
                  value: widget.request.numDice > 1
                      ? '${widget.request.numDice}${widget.request.diceType}'
                      : widget.request.diceType,
                ),
                if (widget.request.modifier != 0)
                  _buildInfoChip(
                    label: 'Модификатор',
                    value: widget.request.modifier > 0
                        ? '+${widget.request.modifier}'
                        : '${widget.request.modifier}',
                  ),
                if (widget.request.dc != null)
                  _buildInfoChip(
                    label: 'DC',
                    value: '${widget.request.dc}',
                  ),
                if (widget.request.skill != null)
                  _buildInfoChip(
                    label: 'Навык',
                    value: widget.request.skill!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Кнопка броска
          ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRolling ? null : _rollDice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: AppColors.secondary.withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.casino,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isRolling ? 'Бросаю...' : 'Бросить ${widget.request.diceType.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required String label, required String value}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurface.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
}
