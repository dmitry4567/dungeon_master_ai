import 'dart:async';

import 'package:ai_dungeon_master/features/game_session/ui/widgets/theme_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/themed_icon_button.dart';
import '../../character/bloc/character_bloc.dart';
import '../../character/bloc/character_event.dart';
import '../../character/bloc/character_state.dart';
import '../../character/models/character.dart';
import '../bloc/lobby_bloc.dart';
import '../bloc/lobby_event.dart';
import '../bloc/lobby_state.dart';
import '../models/room.dart';
import 'widgets/player_avatar.dart';

class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({required this.roomId, super.key});
  final String roomId;

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  Timer? _refreshTimer;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadRoom();
    _loadCurrentUserId();
    // Poll for room updates every 5 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshRoom(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await getIt<SecureStorage>().getUserId();
    if (mounted) {
      setState(() => _currentUserId = userId);
    }
  }

  void _loadRoom() {
    context.read<LobbyBloc>().add(LobbyEvent.loadRoom(roomId: widget.roomId));
  }

  void _refreshRoom() {
    context
        .read<LobbyBloc>()
        .add(LobbyEvent.refreshRoom(roomId: widget.roomId));
  }

  void _approvePlayer(String playerId) {
    context.read<LobbyBloc>().add(
          LobbyEvent.approvePlayer(
            roomId: widget.roomId,
            playerId: playerId,
          ),
        );
  }

  void _declinePlayer(String playerId) {
    context.read<LobbyBloc>().add(
          LobbyEvent.declinePlayer(
            roomId: widget.roomId,
            playerId: playerId,
          ),
        );
  }

  void _startGame() {
    context.read<LobbyBloc>().add(LobbyEvent.startGame(roomId: widget.roomId));
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<LobbyBloc, LobbyState>(
        listener: (context, state) {
          state.whenOrNull(
            roomDetail: (room, isHost) {
              // Если комната активна и текущий пользователь — участник или хост
              if (room.status == 'active' && _currentUserId != null) {
                final isParticipant = room.players.any(
                  (p) =>
                      p.userId == _currentUserId &&
                      p.status != 'declined' &&
                      (p.isHost ||
                          p.status == 'ready' ||
                          p.status == 'approved'),
                );
                if (isParticipant) {
                  _refreshTimer?.cancel();
                  context.pushReplacement(
                    Routes.gameSessionPath(room.id, title: room.name),
                  );
                }
              }
            },
            gameStarting: (room, session) {
              _refreshTimer?.cancel();
              _showCountdownAndNavigate(room, session.id);
            },
            error: (message) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            },
          );
        },
        builder: (context, state) => state.when(
          initial: () => _buildScaffold(
            body: const Center(child: Text('Загрузка...')),
          ),
          loading: () => _buildScaffold(
            body: const Center(child: DetailSkeleton()),
          ),
          loaded: (_) => _buildScaffold(
            body: const Center(child: Text('Загрузка комнаты...')),
          ),
          creating: () => _buildScaffold(
            body: const Center(child: CircularProgressIndicator()),
          ),
          roomDetail: _buildRoomContent,
          gameStarting: (room, _) => _buildRoomContent(room, false),
          error: (message) => _buildScaffold(
            body: ErrorView(message: message, onRetry: _loadRoom),
          ),
        ),
      );

  Widget _buildScaffold({required Widget body}) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Комната ожидания',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        body: body,
      );

  Widget _buildRoomContent(Room room, bool isHost) {
    final nonDeclinedPlayers =
        room.players.where((p) => p.status != 'declined').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        title: Text(
          room.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        leading: ThemeButton(
          onTap: () => context.pop(),
          icon: Icons.arrow_back,
        ),
        actions: [
          ThemedIconButton(
            icon: Icons.refresh,
            onPressed: _refreshRoom,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          // Room info header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A4E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.scenario != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_stories,
                        size: 14,
                        color: Color(0xFFD4AF37),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          room.scenario!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Игроки: ${room.activePlayerCount}/${room.maxPlayers}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: room.status),
                  ],
                ),
              ],
            ),
          ),

          // Players list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: nonDeclinedPlayers.length,
              itemBuilder: (context, index) {
                final player = nonDeclinedPlayers[index];
                final isCurrentUser = player.userId == _currentUserId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PlayerAvatar(
                    player: player,
                    isCurrentUser: isCurrentUser,
                    onApprove: isHost ? () => _approvePlayer(player.id) : null,
                    onDecline: isHost ? () => _declinePlayer(player.id) : null,
                  ),
                );
              },
            ),
          ),

          // Bottom actions
          _buildBottomActions(room, isHost),
        ],
      ),
    );
  }

  Widget _buildBottomActions(Room room, bool isHost) {
    final currentPlayer =
        room.players.where((p) => p.userId == _currentUserId).firstOrNull;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D1A),
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A4E)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isHost && currentPlayer?.status != 'ready') ...[
              _ActionBtn(
                icon: Icons.person_add_outlined,
                label: 'Выбрать персонажа',
                onPressed: () => _showCharacterSelector(context),
              ),
              const SizedBox(height: 8),
              const Text(
                'Выберите персонажа перед началом игры',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ] else if (isHost && currentPlayer?.status == 'ready') ...[
              _ActionBtn(
                icon: Icons.play_arrow,
                label: 'Начать игру',
                isPrimary: true,
                onPressed: room.allPlayersReady && room.activePlayerCount >= 2
                    ? _startGame
                    : null,
              ),
              const SizedBox(height: 8),
              _ActionBtn(
                icon: Icons.swap_horiz,
                label: 'Сменить персонажа',
                onPressed: () => context.read<LobbyBloc>().add(
                      LobbyEvent.toggleReady(
                        roomId: widget.roomId,
                        ready: false,
                      ),
                    ),
              ),
              if (!room.allPlayersReady)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Все игроки должны быть готовы',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              if (room.activePlayerCount < 2)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Нужно минимум 2 игрока',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
            ] else if (currentPlayer != null &&
                currentPlayer.status == 'approved') ...[
              _ActionBtn(
                icon: Icons.check_circle_outline,
                label: 'Выбрать персонажа и готов',
                onPressed: () => _showCharacterSelector(context),
              ),
            ] else if (currentPlayer != null &&
                currentPlayer.status == 'ready') ...[
              _ActionBtn(
                icon: Icons.cancel_outlined,
                label: 'Отменить готовность',
                onPressed: () => context.read<LobbyBloc>().add(
                      LobbyEvent.toggleReady(
                        roomId: widget.roomId,
                        ready: false,
                      ),
                    ),
              ),
            ] else if (currentPlayer != null &&
                currentPlayer.status == 'pending') ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4A261).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF4A261).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFF4A261),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Ожидание одобрения хоста...',
                      style: TextStyle(
                        color: Color(0xFFF4A261),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _ActionBtn(
                icon: Icons.login,
                label: 'Присоединиться',
                isPrimary: true,
                onPressed: () => context.read<LobbyBloc>().add(
                      LobbyEvent.joinRoom(roomId: widget.roomId),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCharacterSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => BlocProvider(
        create: (_) =>
            getIt<CharacterBloc>()..add(const CharacterEvent.loadCharacters()),
        child: _CharacterSelectorSheet(
          onSelected: (character) {
            Navigator.of(sheetContext).pop();
            context.read<LobbyBloc>().add(
                  LobbyEvent.toggleReady(
                    roomId: widget.roomId,
                    characterId: character.id,
                    ready: true,
                  ),
                );
          },
        ),
      ),
    );
  }

  void _showCountdownAndNavigate(Room room, String sessionId) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CountdownDialog(
        onFinished: () {
          Navigator.of(dialogContext).pop();
          context.pushReplacement(
            Routes.gameSessionPath(room.id, title: room.name),
          );
        },
      ),
    );
  }
}

/// Character selector bottom sheet
class _CharacterSelectorSheet extends StatelessWidget {
  const _CharacterSelectorSheet({required this.onSelected});
  final void Function(Character) onSelected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A5E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Выберите персонажа',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: BlocBuilder<CharacterBloc, CharacterState>(
                builder: (context, state) => state.when(
                  initial: () => const Center(
                    child: Text(
                      'Загрузка...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  loaded: (characters) {
                    if (characters.isEmpty) {
                      return const Center(
                        child: Text(
                          'Нет персонажей. Создайте персонажа.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: characters.length,
                      itemBuilder: (context, index) {
                        final character = characters[index];
                        return InkWell(
                          onTap: () => onSelected(character),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0D1A),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFF2A2A4E)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF2A2A4A),
                                    border: Border.all(
                                      color: const Color(0xFFD4AF37),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      character.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        character.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${character.characterClass} · ${character.race} · Ур. ${character.level}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF3A3A5E),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  creating: (_) => const SizedBox.shrink(),
                  submitting: (_) => const SizedBox.shrink(),
                  created: (_) => const SizedBox.shrink(),
                  deleted: (_) => const SizedBox.shrink(),
                  detail: (_) => const SizedBox.shrink(),
                  error: (message, _) => Center(
                    child: Text(
                      'Ошибка: $message',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Кнопка действия в стиле AppColors
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? (enabled
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFFD4AF37).withValues(alpha: 0.3))
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? Colors.transparent : const Color(0xFF2A2A4E),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary
                  ? (enabled ? Colors.black : Colors.black45)
                  : const Color(0xFFD4AF37),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? (enabled ? Colors.black : Colors.black45)
                    : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Countdown dialog (3-2-1-Поехали!)
class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startCountdown();
  }

  void _startCountdown() {
    _controller.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_count > 1) {
        setState(() => _count--);
        _controller.forward(from: 0);
      } else {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _controller,
            curve: Curves.elasticOut,
          ),
          child: Center(
            child: Text(
              _count > 0 ? '$_count' : 'Поехали!',
              style: const TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 20,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Status badge widget
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _getColor().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getText(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getColor(),
          ),
        ),
      );

  Color _getColor() => switch (status) {
        'waiting' => Colors.orange,
        'active' => Colors.green,
        'completed' => Colors.grey,
        _ => Colors.grey,
      };

  String _getText() => switch (status) {
        'waiting' => 'Ожидание игроков',
        'active' => 'Игра идёт',
        'completed' => 'Завершена',
        _ => status,
      };
}
