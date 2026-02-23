import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../bloc/game_session_bloc.dart';
import '../bloc/game_session_event.dart';
import '../bloc/game_session_state.dart';
import 'widgets/dice_roll_request_widget.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';
import 'widgets/world_state_bar.dart';

/// Основная страница игровой сессии
class GameSessionPage extends StatefulWidget {
  const GameSessionPage({required this.roomId, super.key});

  final String roomId;

  @override
  State<GameSessionPage> createState() => _GameSessionPageState();
}

class _GameSessionPageState extends State<GameSessionPage> {
  final _scrollController = ScrollController();
  int _previousMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Считаем "внизу" если в пределах 100 пикселей от низа
    return maxScroll - currentScroll <= 100;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<GameSessionBloc, GameSessionState>(
      listener: (context, state) {
        if (state is GameSessionActive) {
          final currentCount = state.messages.length;
          final hasNewMessage = currentCount > _previousMessageCount;
          final isStreaming = state.streamingContent != null;

          // Скроллим только если: новое сообщение и пользователь уже внизу, или идёт стриминг
          if ((hasNewMessage && _isNearBottom()) || isStreaming) {
            _scrollToBottom();
          }
          _previousMessageCount = currentCount;
        }
        if (state is GameSessionEnded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сессия завершена')),
          );
        }
      },
      builder: (context, state) => Scaffold(
          backgroundColor: AppColors.background,
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _showLeaveDialog(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories, color: AppColors.secondary, size: 20),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Игровая сессия',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16),
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

  Widget _buildBody(BuildContext context, GameSessionState state) => switch (state) {
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
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
    final hasPendingDiceRequest = state.pendingDiceRequest != null;

    return Column(
      children: [
        // Панель состояния мира
        WorldStateBar(worldState: state.worldState),
        // Список сообщений
        Expanded(
          child: Stack(
            children: [
              _buildMessageList(state),
              // Запрос на бросок кубика поверх чата
              if (hasPendingDiceRequest)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DiceRollRequestWidget(
                    request: state.pendingDiceRequest!,
                  ),
                ),
            ],
          ),
        ),
        // Поле ввода (скрыто, когда ждём бросок кубика)
        if (!hasPendingDiceRequest)
          MessageInput(
            onSend: (content) {
              context
                  .read<GameSessionBloc>()
                  .add(GameSessionEvent.sendMessage(content: content));
            },
            isStreaming: isStreaming,
          ),
      ],
    );
  }

  Widget _buildMessageList(GameSessionActive state) {
    final messages = state.messages;
    final itemCount =
        messages.length + (state.streamingContent != null ? 1 : 0);

    if (messages.isEmpty && state.streamingContent == null) {
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
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Стриминг-пузырь в конце
        if (index == messages.length && state.streamingContent != null) {
          return StreamingBubble(content: state.streamingContent!);
        }

        final message = messages[index];

        return MessageBubble(
          message: message,
        );
      },
    );
  }

  Widget _buildEndedSession(BuildContext context, GameSessionEnded state) => Column(
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
      'error' => (AppColors.error, Icons.wifi_off),
      _ => (AppColors.outline, Icons.wifi_off),
    };

    return Icon(icon, color: color, size: 16);
  }
}
