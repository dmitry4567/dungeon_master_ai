import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/di/injection.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
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
  final String roomId;

  const WaitingRoomPage({super.key, required this.roomId});

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
    context
        .read<LobbyBloc>()
        .add(LobbyEvent.startGame(roomId: widget.roomId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LobbyBloc, LobbyState>(
      listener: (context, state) {
        state.whenOrNull(
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
      builder: (context, state) {
        return state.when(
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
          roomDetail: (room, isHost) => _buildRoomContent(room, isHost),
          gameStarting: (room, _) => _buildRoomContent(room, false),
          error: (message) => _buildScaffold(
            body: ErrorView(message: message, onRetry: _loadRoom),
          ),
        );
      },
    );
  }

  Widget _buildScaffold({required Widget body}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Комната ожидания')),
      body: body,
    );
  }

  Widget _buildRoomContent(Room room, bool isHost) {
    final nonDeclinedPlayers =
        room.players.where((p) => p.status != 'declined').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        actions: [
          IconButton(
            onPressed: _refreshRoom,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          // Room info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.scenario != null)
                  Text(
                    'Сценарий: ${room.scenario!.title}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: 4),
                Text(
                  'Игроки: ${room.activePlayerCount}/${room.maxPlayers}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                _StatusBadge(status: room.status),
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
                    onApprove:
                        isHost ? () => _approvePlayer(player.id) : null,
                    onDecline:
                        isHost ? () => _declinePlayer(player.id) : null,
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
    final currentPlayer = room.players
        .where((p) => p.userId == _currentUserId)
        .firstOrNull;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isHost) ...[
              // Host: start game button
              ElevatedButton.icon(
                onPressed: room.allPlayersReady &&
                        room.activePlayerCount >= 2
                    ? _startGame
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Начать игру'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              if (!room.allPlayersReady)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Все игроки должны быть готовы',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              if (room.activePlayerCount < 2)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Нужно минимум 2 игрока',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
            ] else if (currentPlayer != null &&
                currentPlayer.status == 'approved') ...[
              // Approved player: ready/character selection
              ElevatedButton.icon(
                onPressed: () => _showCharacterSelector(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Выбрать персонажа и готов'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ] else if (currentPlayer != null &&
                currentPlayer.status == 'ready') ...[
              // Ready player: unready
              OutlinedButton.icon(
                onPressed: () {
                  context.read<LobbyBloc>().add(
                        LobbyEvent.toggleReady(
                          roomId: widget.roomId,
                          characterId: currentPlayer.character?.id ?? '',
                          ready: false,
                        ),
                      );
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Отменить готовность'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ] else if (currentPlayer != null &&
                currentPlayer.status == 'pending') ...[
              const Center(
                child: Text(
                  'Ожидание одобрения хоста...',
                  style: TextStyle(color: Colors.orange, fontSize: 16),
                ),
              ),
            ] else ...[
              // Not in room: join
              ElevatedButton.icon(
                onPressed: () {
                  context.read<LobbyBloc>().add(
                        LobbyEvent.joinRoom(roomId: widget.roomId),
                      );
                },
                icon: const Icon(Icons.login),
                label: const Text('Присоединиться'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
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
        create: (_) => getIt<CharacterBloc>()
          ..add(const CharacterEvent.loadCharacters()),
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
          context.pushReplacement(Routes.gameSessionPath(room.id));
        },
      ),
    );
  }
}

/// Character selector bottom sheet
class _CharacterSelectorSheet extends StatelessWidget {
  final void Function(Character) onSelected;

  const _CharacterSelectorSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выберите персонажа',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Flexible(
            child: BlocBuilder<CharacterBloc, CharacterState>(
              builder: (context, state) {
                return state.when(
                  initial: () => const Center(child: Text('Загрузка...')),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  loaded: (characters) {
                    if (characters.isEmpty) {
                      return const Center(
                        child: Text('Нет персонажей. Создайте персонажа.'),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: characters.length,
                      itemBuilder: (context, index) {
                        final character = characters[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(character.name[0].toUpperCase()),
                          ),
                          title: Text(character.name),
                          subtitle: Text(
                            '${character.characterClass} • ${character.race} • Ур. ${character.level}',
                          ),
                          onTap: () => onSelected(character),
                        );
                      },
                    );
                  },
                  creating: (_) => const SizedBox.shrink(),
                  submitting: (_) => const SizedBox.shrink(),
                  created: (_) => const SizedBox.shrink(),
                  deleted: (_) => const SizedBox.shrink(),
                  detail: (_) => const SizedBox.shrink(),
                  error: (message, _) =>
                      Center(child: Text('Ошибка: $message')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Countdown dialog (3-2-1-Поехали!)
class _CountdownDialog extends StatefulWidget {
  final VoidCallback onFinished;

  const _CountdownDialog({required this.onFinished});

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
  Widget build(BuildContext context) {
    return Dialog(
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
}

/// Status badge widget
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
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
  }

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
