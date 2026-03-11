import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../bloc/game_session_bloc.dart';
import '../../bloc/game_session_event.dart';
import '../../models/dice_result.dart';

/// Компактный виджет запроса на бросок кубика, встраиваемый в чат
class DiceRollRequestWidget extends StatefulWidget {
  const DiceRollRequestWidget({required this.request, super.key});

  final DiceRequest request;

  @override
  State<DiceRollRequestWidget> createState() => _DiceRollRequestWidgetState();
}

class _DiceRollRequestWidgetState extends State<DiceRollRequestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _rollDice() {
    if (_isRolling) return;

    setState(() {
      _isRolling = true;
    });

    final random = Random();
    final dieSize = _parseDieSize(widget.request.diceType);
    final rolls = List.generate(
      widget.request.numDice,
      (_) => random.nextInt(dieSize) + 1,
    );

    context.read<GameSessionBloc>().add(
          RollDiceEvent(
            requestId: widget.request.requestId,
            rolls: rolls,
          ),
        );
  }

  int _parseDieSize(String diceType) {
    final match = RegExp(r'd(\d+)').firstMatch(diceType.toLowerCase());
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 20;
    }
    return 20;
  }

  @override
  Widget build(BuildContext context) {
    final diceNotation = widget.request.numDice > 1
        ? '${widget.request.numDice}${widget.request.diceType}'
        : widget.request.diceType.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D2418), Color(0xFF352A1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок DM
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_stories,
                  color: AppColors.secondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Dungeon Master',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary
                          .withValues(alpha: _pulseAnimation.value),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ваш ход',
                      style: TextStyle(
                        color: AppColors.onSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Причина броска
          if (widget.request.reason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                widget.request.reason!,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Компактная карточка броска
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary
                        .withValues(alpha: _pulseAnimation.value),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isRolling ? null : _rollDice,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Иконка кубика
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.secondary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: _isRolling
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.secondary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.casino,
                                      color: AppColors.secondary,
                                      size: 24,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Информация о броске
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Тип кубика и навык
                                Row(
                                  children: [
                                    Text(
                                      diceNotation,
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (widget.request.modifier != 0) ...[
                                      Text(
                                        widget.request.modifier > 0
                                            ? ' +${widget.request.modifier}'
                                            : ' ${widget.request.modifier}',
                                        style: TextStyle(
                                          color: AppColors.onSurface
                                              .withValues(alpha: 0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                    if (widget.request.skill != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryLight
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          widget.request.skill!,
                                          style: const TextStyle(
                                            color: AppColors.secondaryLight,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                // DC
                                if (widget.request.dc != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Сложность: ${widget.request.dc}',
                                      style: TextStyle(
                                        color: AppColors.onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Кнопка
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _isRolling
                                  ? AppColors.secondary.withValues(alpha: 0.5)
                                  : AppColors.secondary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isRolling ? '...' : 'Бросить',
                              style: const TextStyle(
                                color: AppColors.onSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
