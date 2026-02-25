import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../bloc/lobby_bloc.dart';
import '../bloc/lobby_event.dart';
import '../bloc/lobby_state.dart';
import 'widgets/room_card.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _isInitialized = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем данные при возврате на страницу (когда пользователь вышел из игры)
    if (_isInitialized) {
      _loadRooms();
    }
  }

  void _loadRooms() {
    context.read<LobbyBloc>().add(const LobbyEvent.loadRooms());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Игровое лобби',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRooms,
            ),
          ],
        ),
        body: BlocConsumer<LobbyBloc, LobbyState>(
          listener: (context, state) {
            // Handle state changes if needed
          },
          builder: (context, state) => state.when(
            initial: () => const Center(
              child: Text('Создайте или присоединитесь к комнате'),
            ),
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LoadingSkeleton(height: 120),
              ),
            ),
            loaded: (rooms) {
              if (rooms.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Нет активных комнат',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Нажмите + чтобы создать новую',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<LobbyBloc>().add(const LobbyEvent.loadRooms());
                  // Wait for state to update
                  await Future<void>.delayed(const Duration(milliseconds: 300));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RoomCard(
                        room: room,
                        onTap: () {
                          if (room.status == 'active' &&
                              room.isCurrentUserPlayer) {
                            context.push(
                              Routes.gameSessionPath(room.id, title: room.name),
                            );
                          } else {
                            context.push(Routes.waitingRoomPath(room.id));
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            },
            creating: () => const Center(child: CircularProgressIndicator()),
            roomDetail: (_, __) => const SizedBox.shrink(),
            gameStarting: (_, __) => const SizedBox.shrink(),
            error: (message) => ErrorView(
              message: message,
              onRetry: _loadRooms,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.roomCreate),
          icon: const Icon(Icons.add),
          label: const Text('Создать'),
        ),
      );
}
