import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../bloc/game_session_bloc.dart';
import '../bloc/game_session_event.dart';
import '../bloc/game_session_state.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';
import 'widgets/world_state_bar.dart';

/// Основная страница игровой сессии
class GameSessionPage extends StatefulWidget {
  const GameSessionPage({
    required this.roomId,
    required this.title,
    super.key,
  });

  final String roomId;
  final String title;

  @override
  State<GameSessionPage> createState() => _GameSessionPageState();
}

class _GameSessionPageState extends State<GameSessionPage> {
  final _scrollController = ScrollController();
  DateTime? _lastScrollTime;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Для reverse: true maxScrollExtent = 0 (начало списка)
        if (smooth) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          // Для быстрого скролла при стриминге
          _scrollController.jumpTo(
            0,
          );
        }
      }
    });
  }

  bool _shouldScrollForStreaming() {
    // Ограничиваем частоту скролла во время стриминга до 1 раза в 100мс
    final now = DateTime.now();
    if (_lastScrollTime == null ||
        now.difference(_lastScrollTime!) > const Duration(milliseconds: 100)) {
      _lastScrollTime = now;
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<GameSessionBloc, GameSessionState>(
        listener: (context, state) {
          if (state is GameSessionActive) {
            final isStreaming = state.streamingContent != null;

            // Скролл только во время стриминга ответа DM (не при отправке своего сообщения)
            if (isStreaming && _shouldScrollForStreaming()) {
              _scrollToBottom(smooth: false);
            }
          }
          if (state is GameSessionEnded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Сессия завершена')),
            );
          }
        },
        builder: (context, state) => Scaffold(
          backgroundColor: AppColors.background,
          resizeToAvoidBottomInset: true,
          appBar: _buildAppBar(context, state),
          body: _buildBody(context, state),
        ),
      );

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    GameSessionState state,
  ) {
    final connectionIndicator = state is GameSessionActive
        ? _ConnectionIndicator(state: state.connectionState)
        : null;

    return AppBar(
      backgroundColor: AppColors.surface,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _showLeaveDialog(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories, color: AppColors.secondary, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (connectionIndicator != null) ...[
            const SizedBox(width: 8),
            connectionIndicator,
          ],
        ],
      ),
      actions: [
        if (state is GameSessionActive && state.isHost)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'end') {
                _showEndDialog(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'end',
                child: Row(
                  children: [
                    Icon(Icons.stop, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Завершить игру'),
                  ],
                ),
              ),
            ],
          )
        else
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _showLeaveDialog(context),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, GameSessionState state) =>
      switch (state) {
        GameSessionInitial() || GameSessionConnecting() => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.secondary),
                SizedBox(height: 16),
                Text(
                  'Подключение к сессии...',
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ],
            ),
          ),
        GameSessionActive() => _buildActiveSession(context, state),
        GameSessionEnded() => _buildEndedSession(context, state),
        GameSessionError() => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.onSurface),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Вернуться'),
                ),
              ],
            ),
          ),
        _ => const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          ),
      };

  Widget _buildActiveSession(BuildContext context, GameSessionActive state) {
    final isStreaming = state.streamingContent != null;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          // Панель состояния мира
          WorldStateBar(worldState: state.worldState),
          // Список сообщений
          Expanded(
            child: _buildMessageList(context, state),
          ),
          // Поле ввода
          MessageInput(
            onSend: (content) {
              context
                  .read<GameSessionBloc>()
                  .add(GameSessionEvent.sendMessage(content: content));
            },
            isStreaming: isStreaming,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, GameSessionActive state) {
    final messages = state.messages;
    final hasStreaming = state.streamingContent != null;

    if (messages.isEmpty && !hasStreaming) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.outline),
            SizedBox(height: 16),
            Text(
              'Начните приключение!\nОпишите действие вашего персонажа.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      reverse: true,
      itemCount: messages.length + (hasStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        // Из-за reverse: true, индекс 0 - это низ списка
        // Стриминг-пузырь должен быть внизу (индекс 0)
        if (index == 0 && hasStreaming) {
          return StreamingBubble(content: state.streamingContent!);
        }
        // Сообщения: сдвигаем индекс на 1 из-за стриминг-пузыря внизу
        final messageIndex = hasStreaming ? index - 1 : index;
        return MessageBubble(message: messages[messages.length - 1 - messageIndex]);
      },
    );
  }

  Widget _buildEndedSession(BuildContext context, GameSessionEnded state) =>
      Column(
        children: [
          // Баннер завершения
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.surfaceVariant,
            child: const Column(
              children: [
                Icon(Icons.flag, color: AppColors.secondary, size: 32),
                SizedBox(height: 8),
                Text(
                  'Сессия завершена',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          // История сообщений (только чтение)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final message = state.messages[index];
                return MessageBubble(
                  message: message,
                );
              },
            ),
          ),
          // Кнопка выхода
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Вернуться в лобби'),
              ),
            ),
          ),
        ],
      );

  void _showLeaveDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Покинуть сессию?'),
        content: const Text('Вы уверены, что хотите покинуть игру?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              context
                  .read<GameSessionBloc>()
                  .add(const GameSessionEvent.leaveSession());
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );
  }

  void _showEndDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Завершить игру?'),
        content: const Text(
          'Сессия будет завершена для всех игроков. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              context
                  .read<GameSessionBloc>()
                  .add(const GameSessionEvent.endSession());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
  }
}

/// Индикатор состояния соединения
class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      'connected' => (AppColors.success, Icons.wifi),
      'connecting' || 'reconnecting' => (AppColors.warning, Icons.wifi_find),
      'disconnected' => (AppColors.warning, Icons.wifi_off),
      'error' => (AppColors.error, Icons.wifi_off),
      _ => (AppColors.outline, Icons.wifi_off),
    };

    return Icon(icon, color: color, size: 16);
  }
}
