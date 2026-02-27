import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

/// Поле ввода действий игрока
class MessageInput extends StatefulWidget {
  const MessageInput({
    required this.onSend,
    super.key,
    this.enabled = true,
    this.isStreaming = false,
  });

  final ValueChanged<String> onSend;
  final bool enabled;
  final bool isStreaming;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool get _canSend =>
      widget.enabled &&
      !widget.isStreaming &&
      _controller.text.trim().isNotEmpty;

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled || widget.isStreaming) return;

    widget.onSend(text);
    _controller.clear();
    _focusNode.unfocus(); // Скрываем клавиатуру после отправки
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: const BoxDecoration(
            // color: AppColors.surface,
            // border: Border(
            //   top: BorderSide(
            //     color: AppColors.outline.withValues(alpha: 0.3),
            //   ),
            // ),
            ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled && !widget.isStreaming,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: widget.isStreaming
                      ? 'DM отвечает...'
                      : 'Ваше действие...',
                  hintStyle: TextStyle(
                    color: AppColors.onSurface.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0D0D1A),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:  BorderSide(
                      color: const Color(0xFF2A2A4E).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFF2A2A4E),
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                onPressed: _canSend ? _handleSend : null,
                icon: Icon(
                  Icons.send_rounded,
                  color: _canSend
                      ? AppColors.secondary
                      : AppColors.onSurface.withValues(alpha: 0.3),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _canSend
                      ? AppColors.secondary.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      );
}
