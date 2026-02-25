import 'dart:math';

import 'package:ai_dungeon_master/features/auth/bloc/auth_bloc.dart';
import 'package:ai_dungeon_master/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/colors.dart';
import '../../bloc/game_session_bloc.dart';
import '../../bloc/game_session_event.dart';
import '../../bloc/game_session_state.dart';
import '../../models/message.dart';
import 'dice_result_widget.dart';

/// Распарсенный запрос на бросок из текста сообщения
class ParsedDiceRequest {
  const ParsedDiceRequest({
    required this.diceType,
    required this.modifier,
    required this.dc,
    required this.reason,
    required this.originalText,
  });

  final String diceType; // d20, d6, etc.
  final int modifier;
  final int? dc;
  final String? reason;
  final String originalText;

  /// Парсит текст формата [DICE: d20+2 DC:15 Reason:Some reason]
  static ParsedDiceRequest? tryParse(String content) {
    // Ищем паттерн [DICE: ...] или [ДICE: ...] (с русской Д)
    final regex = RegExp(
      r'\[D?[ДД]?ICE:\s*([^\]]+)\]',
      caseSensitive: false,
    );
    final match = regex.firstMatch(content);
    if (match == null) return null;

    final fullMatch = match.group(0)!;
    final innerContent = match.group(1)!;

    // Парсим dice type и modifier: d20+2, d20-1, d20, 2d6+3
    final diceRegex = RegExp(r'(\d*d\d+)([+-]\d+)?', caseSensitive: false);
    final diceMatch = diceRegex.firstMatch(innerContent);
    if (diceMatch == null) return null;

    final diceType = diceMatch.group(1)!.toLowerCase();
    final modifierStr = diceMatch.group(2);
    final modifier = modifierStr != null ? int.tryParse(modifierStr) ?? 0 : 0;

    // Парсим DC
    final dcRegex = RegExp(r'DC:?\s*(\d+)', caseSensitive: false);
    final dcMatch = dcRegex.firstMatch(innerContent);
    final dc = dcMatch != null ? int.tryParse(dcMatch.group(1)!) : null;

    // Парсим Reason
    final reasonRegex =
        RegExp(r'Reason:\s*(.+?)(?:\s*$)', caseSensitive: false);
    final reasonMatch = reasonRegex.firstMatch(innerContent);
    final reason = reasonMatch?.group(1)?.trim();

    return ParsedDiceRequest(
      diceType: diceType,
      modifier: modifier,
      dc: dc,
      reason: reason,
      originalText: fullMatch,
    );
  }
}

/// Пузырь сообщения в чате игровой сессии
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    super.key,
  });

  final Message message;

  @override
  Widget build(BuildContext context) => switch (message.role) {
        MessageRole.player => _buildPlayerBubble(context),
        MessageRole.dm => _DmBubble(message: message),
        MessageRole.system => _buildSystemBubble(context),
      };

  Widget _buildPlayerBubble(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;
    final isCurrentUser = message.authorId == currentUserId;

    // Проверяем, является ли это результатом броска кубика
    final diceRoll = ParsedDiceRoll.tryParse(message.content);
    if (diceRoll != null) {
      // Показываем красивый виджет результата броска
      return AnimatedDiceResultWidget(result: diceRoll);
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? AppColors.primaryDark : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
            bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.authorName != null && !isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.authorName!,
                  style: const TextStyle(
                    color: AppColors.secondaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              message.content,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBubble(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: message.diceResult != null
              ? DiceResultWidget(result: message.diceResult!)
              : Text(
                  message.content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
        ),
      );
}

/// DM bubble с поддержкой inline броска кубиков
class _DmBubble extends StatefulWidget {
  const _DmBubble({required this.message});

  final Message message;

  @override
  State<_DmBubble> createState() => _DmBubbleState();
}

class _DmBubbleState extends State<_DmBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isRolling = false;

  ParsedDiceRequest? _diceRequest;
  String _displayContent = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _parseContent();
  }

  void _parseContent() {
    _diceRequest = ParsedDiceRequest.tryParse(widget.message.content);
    if (_diceRequest != null) {
      // Убираем DICE-тег из отображаемого контента
      _displayContent = widget.message.content
          .replaceAll(_diceRequest!.originalText, '')
          .trim();
      _pulseController.repeat(reverse: true);
    } else {
      _displayContent = widget.message.content;
    }
  }

  @override
  void didUpdateWidget(_DmBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content) {
      _parseContent();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int _parseDieSize(String diceType) {
    final match = RegExp(r'd(\d+)').firstMatch(diceType.toLowerCase());
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 20;
    }
    return 20;
  }

  void _rollDice() {
    if (_isRolling || _diceRequest == null) return;

    // Проверяем, не был ли уже выполнен бросок для этого сообщения
    final bloc = context.read<GameSessionBloc>();
    final state = bloc.state;
    if (state is GameSessionActive &&
        state.rolledMessageIds.contains(widget.message.id)) {
      return;
    }

    setState(() {
      _isRolling = true;
    });

    _pulseController.stop();

    final random = Random();
    final dieSize = _parseDieSize(_diceRequest!.diceType);
    final roll = random.nextInt(dieSize) + 1;

    // Отправляем результат через bloc
    // Формируем сообщение с результатом
    final total = roll + _diceRequest!.modifier;
    final success =
        _diceRequest!.dc != null ? total >= _diceRequest!.dc! : null;

    // Сначала отмечаем сообщение как обработанное, потом отправляем результат
    final resultText = _formatRollResult(roll, total, success);
    bloc
      ..add(GameSessionEvent.markMessageRolled(messageId: widget.message.id))
      ..add(GameSessionEvent.sendMessage(content: resultText));

    setState(() {
      _isRolling = false;
    });
  }

  String _formatRollResult(int roll, int total, bool? success) {
    final buffer = StringBuffer()
      ..write('🎲 Бросок ${_diceRequest!.diceType.toUpperCase()}: $roll');
    if (_diceRequest!.modifier != 0) {
      buffer
        ..write(
          _diceRequest!.modifier > 0
              ? ' + ${_diceRequest!.modifier}'
              : ' - ${_diceRequest!.modifier.abs()}',
        )
        ..write(' = $total');
    }
    if (_diceRequest!.dc != null) {
      buffer.write(' (DC ${_diceRequest!.dc})');
      if (success != null) {
        buffer.write(success ? ' ✓ Успех!' : ' ✗ Провал');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<GameSessionBloc, GameSessionState>(
        buildWhen: (previous, current) {
          // Перестраиваем только когда изменяется rolledMessageIds
          if (previous is GameSessionActive && current is GameSessionActive) {
            return previous.rolledMessageIds != current.rolledMessageIds;
          }
          return true;
        },
        builder: (context, state) {
          final hasRolled = state is GameSessionActive &&
              state.rolledMessageIds.contains(widget.message.id);
          final hasDiceRequest = _diceRequest != null && !hasRolled;

          // Останавливаем анимацию если бросок уже выполнен
          if (hasRolled && _pulseController.isAnimating) {
            _pulseController.stop();
          }

          return _buildContent(context, hasDiceRequest);
        },
      );

  Widget _buildContent(BuildContext context, bool hasDiceRequest) => Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2A2A4E),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок DM
            Row(
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
                if (hasDiceRequest) ...[
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
              ],
            ),
            const SizedBox(height: 8),

            // Содержимое с поддержкой Markdown
            if (_displayContent.isNotEmpty)
              MarkdownBody(
                data: _displayContent,
                selectable: true,
                styleSheet: _markdownStyle,
              ),

            // Inline кнопка броска кубика
            if (hasDiceRequest) ...[
              const SizedBox(height: 12),
              _buildDiceRollButton(),
            ],

            // Результат броска (если уже есть в сообщении)
            if (widget.message.diceResult != null) ...[
              const SizedBox(height: 8),
              DiceResultWidget(result: widget.message.diceResult!),
            ],
          ],
        ),
      );

  Widget _buildDiceRollButton() {
    final req = _diceRequest!;
    final diceNotation = req.diceType.toUpperCase();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: _pulseAnimation.value),
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isRolling ? null : _rollDice,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Верхняя строка: иконка + тип кубика + DC
                  Row(
                    children: [
                      // Иконка кубика
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _isRolling
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.secondary,
                                  ),
                                )
                              : const Icon(
                                  Icons.casino,
                                  color: AppColors.secondary,
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Информация о броске
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  diceNotation,
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                if (req.modifier != 0)
                                  Text(
                                    req.modifier > 0
                                        ? ' +${req.modifier}'
                                        : ' ${req.modifier}',
                                    style: TextStyle(
                                      color: AppColors.onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 18,
                                    ),
                                  ),
                              ],
                            ),
                            if (req.dc != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Сложность: ${req.dc}',
                                    style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Причина броска
                  if (req.reason != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      req.reason!,
                      style: TextStyle(
                        color: AppColors.onSurface.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Кнопка на всю ширину
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isRolling
                            ? AppColors.secondary.withValues(alpha: 0.5)
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _isRolling ? '...' : 'Бросить кубик',
                          style: const TextStyle(
                            color: AppColors.onSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet get _markdownStyle => MarkdownStyleSheet(
        p: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
          height: 1.4,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
        strong: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        em: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
          fontStyle: FontStyle.normal,
        ),
        h1: const TextStyle(
          color: AppColors.secondary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h2: const TextStyle(
          color: AppColors.secondary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h3: const TextStyle(
          color: AppColors.secondary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        listBullet: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
        ),
        code: TextStyle(
          color: AppColors.onSurface,
          backgroundColor: AppColors.surface.withValues(alpha: 0.5),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
      );
}

/// Пузырь для стриминга ответа DM
class StreamingBubble extends StatelessWidget {
  const StreamingBubble({required this.content, super.key});

  final String content;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2D2418),
              Color(0xFF352A1C),
            ],
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
          children: [
            const Row(
              children: [
                Icon(
                  Icons.auto_stories,
                  color: AppColors.secondary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Dungeon Master',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Показываем "думает..." если контент еще пустой или очень короткий
            if (content.trim().isEmpty)
              Text(
                'думает...',
                style: TextStyle(
                  color: AppColors.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  strong: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  em: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    fontStyle: FontStyle.normal,
                  ),
                  h1: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                  ),
                  code: TextStyle(
                    color: AppColors.onSurface,
                    backgroundColor: AppColors.surface.withValues(alpha: 0.5),
                    fontSize: 15,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      );
}
