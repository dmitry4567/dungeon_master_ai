import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/game_session_bloc.dart';
import '../bloc/game_session_event.dart';
import '../bloc/game_session_state.dart';
import '../bloc/voice_cubit.dart';
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

class _GameSessionPageState extends State<GameSessionPage>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _isAtBottom = true;
  bool _userTouching = false;
  bool _listReady = false;
  int _lastMessageCount = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 50;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || _userTouching) return;
      if (_isAtBottom) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<GameSessionBloc, GameSessionState>(
        listener: (context, state) {
          if (state is GameSessionActive) {
            // Автоотключение голосового канала при закрытии сессии
            if (state.voiceChannelClosed) {
              context.read<VoiceCubit>().disconnect();
            }
          }
          if (state is GameSessionEnded) {
            // Отключаем голосовой канал при завершении сессии
            context.read<VoiceCubit>().disconnect();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Сессия завершена'),
                backgroundColor: Color(0xFF52B788),
              ),
            );
          }
        },
        builder: (context, state) => Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
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
      backgroundColor: const Color(0xFF0D0D1A),
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Color(0xFFD4AF37),
            size: 18,
          ),
        ),
        onPressed: () => _showLeaveDialog(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2A4A),
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.castle,
              color: Color(0xFFD4AF37),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Text(
                      'Игровая сессия',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    if (connectionIndicator != null) ...[
                      const SizedBox(width: 8),
                      connectionIndicator,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (state is GameSessionActive && state.isHost)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _showEndDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE76F51).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.stop,
                  color: Color(0xFFE76F51),
                  size: 20,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _showLeaveDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.exit_to_app,
                  color: Color(0xFFD4AF37),
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, GameSessionState state) => switch (state) {
        GameSessionInitial() || GameSessionConnecting() => _buildLoadingView(),
        GameSessionActive() => _buildActiveSession(context, state),
        GameSessionEnded() => _buildEndedSession(context, state),
        GameSessionError() => _buildErrorView(state),
        _ => const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      };

  Widget _buildActiveSession(BuildContext context, GameSessionActive state) {
    final isStreaming = state.streamingContent != null;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Панель состояния мира
          WorldStateBar(
            worldState: state.worldState,
            scenarioContent: state.scenarioContent,
          ),
          // Панель голосового чата
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //   child: VoiceControlsWidget(
          //     roomId: widget.roomId,
          //     isRoomActive: true,
          //   ),
          // ),
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

  Widget _buildLoadingView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFD4AF37),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  const Icon(
                    Icons.castle,
                    color: Color(0xFFD4AF37),
                    size: 28,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Подключение к сессии...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );

  Widget _buildErrorView(GameSessionError state) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE76F51).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE76F51).withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFE76F51),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'Вернуться',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildMessageList(BuildContext context, GameSessionActive state) {
    final messages = state.messages;
    final hasStreaming = state.streamingContent != null;

    if (messages.isEmpty && !hasStreaming) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A2A4E)),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Color(0xFF3A3A5E),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Начните приключение!\nОпишите действие вашего персонажа.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_listReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        if (mounted) setState(() => _listReady = true);
      });
    } else {
      if (messages.length > _lastMessageCount) {
        // Новое сообщение — плавный скролл вниз
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      } else if (hasStreaming && _isAtBottom) {
        _scrollToBottom();
      }
    }
    _lastMessageCount = messages.length;

    return Offstage(
      offstage: !_listReady,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _userTouching = true;
          } else if (notification is ScrollEndNotification) {
            _userTouching = false;
          }
          return false;
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const ClampingScrollPhysics(),
          itemCount: messages.length + (hasStreaming ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length && hasStreaming) {
              return StreamingBubble(content: state.streamingContent!);
            }
            return MessageBubble(message: messages[index]);
          },
        ),
        ),
      ),
    );
  }

  Widget _buildEndedSession(BuildContext context, GameSessionEnded state) => Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF52B788).withOpacity(0.15),
                  const Color(0xFF52B788).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF52B788).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Color(0xFF52B788),
                  size: 40,
                ),
                SizedBox(height: 12),
                Text(
                  'Сессия завершена',
                  style: TextStyle(
                    color: Color(0xFF52B788),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final message = state.messages[index];
                return MessageBubble(message: message);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              border: Border(
                top: BorderSide(color: Color(0xFF2A2A4E), width: 1.5),
              ),
            ),
            child: SafeArea(
              child: InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home,
                        color: Color(0xFFD4AF37),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Вернуться в лобби',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  void _showLeaveDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Покинуть сессию?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Вы уверены, что хотите покинуть игру?',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE76F51),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              context
                  .read<GameSessionBloc>()
                  .add(const GameSessionEvent.leaveSession());
              context.pop();
            },
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
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Завершить игру?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Сессия будет завершена для всех игроков. Это действие нельзя отменить.',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE76F51),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              context
                  .read<GameSessionBloc>()
                  .add(const GameSessionEvent.endSession());
            },
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
      'connected' => (const Color(0xFF52B788), Icons.wifi),
      'connecting' || 'reconnecting' => (const Color(0xFFF4A261), Icons.wifi_find),
      'disconnected' => (const Color(0xFFF4A261), Icons.wifi_off),
      'error' => (const Color(0xFFE76F51), Icons.wifi_off),
      _ => (const Color(0xFF3A3A5E), Icons.wifi_off),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            state == 'connected' ? 'Онлайн' : state,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
