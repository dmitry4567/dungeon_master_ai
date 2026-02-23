import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../models/message.dart';
import 'dice_result_widget.dart';

/// Пузырь сообщения в чате игровой сессии
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.isCurrentUser = false,
  });

  final Message message;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return switch (message.role) {
      MessageRole.player => _buildPlayerBubble(context),
      MessageRole.dm => _buildDmBubble(context),
      MessageRole.system => _buildSystemBubble(context),
    };
  }

  Widget _buildPlayerBubble(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? AppColors.primaryDark : AppColors.surfaceVariant,
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

  Widget _buildDmBubble(BuildContext context) {
    return Container(
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
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок DM
          Row(
            children: [
              Icon(
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
            ],
          ),
          const SizedBox(height: 8),
          // Содержимое
          Text(
            message.content,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          // Бросок кубиков
          if (message.diceResult != null) ...[
            const SizedBox(height: 8),
            DiceResultWidget(result: message.diceResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemBubble(BuildContext context) {
    return Center(
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
                  fontStyle: FontStyle.italic,
                ),
              ),
      ),
    );
  }
}

/// Пузырь для стриминга ответа DM
class StreamingBubble extends StatelessWidget {
  const StreamingBubble({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
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
              const SizedBox(width: 8),
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
          Text(
            content,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
