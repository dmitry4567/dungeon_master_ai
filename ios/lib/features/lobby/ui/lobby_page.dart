import 'package:ai_dungeon_master/features/lobby/models/room.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _LobbyPageState extends State<LobbyPage>
    with SingleTickerProviderStateMixin {
  bool _isInitialized = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _isInitialized = true;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) {
      _loadRooms();
    }
  }

  void _loadRooms() {
    context.read<LobbyBloc>().add(const LoadRoomsEvent());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: BlocConsumer<LobbyBloc, LobbyState>(
          listener: (context, state) {
            // Handle state changes if needed
          },
          builder: (context, state) {
            if (state is LobbyInitial) {
              return _buildInitialState();
            }
            if (state is LobbyLoading) {
              return _buildLoadingView();
            }
            if (state is LobbyLoaded) {
              return _buildLoadedView(state.rooms);
            }
            if (state is LobbyCreating) {
              return _buildCreatingView();
            }
            if (state is LobbyRoomDetail) {
              return const SizedBox.shrink();
            }
            if (state is LobbyGameStarting) {
              return const SizedBox.shrink();
            }
            if (state is LobbyError) {
              return _buildErrorView(state.message);
            }
            return _buildLoadingView();
          },
        ),
      );

  Widget _buildInitialState() => Center(
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
                Icons.meeting_room_outlined,
                size: 64,
                color: Color(0xFF3A3A5E),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Добро пожаловать в лобби',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Создайте или присоединитесь к комнате',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );

  Widget _buildLoadingView() => CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LoadingSkeleton(height: 140, borderRadius: 16),
                ),
                childCount: 4,
              ),
            ),
          ),
        ],
      );

  Widget _buildLoadedView(List<RoomSummary> rooms) => RefreshIndicator(
        color: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF1A1A2E),
        onRefresh: () async {
          context.read<LobbyBloc>().add(const LoadRoomsEvent());
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            if (rooms.isEmpty)
              const SliverFillRemaining(child: _EmptyView())
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.meeting_room,
                        color: Color(0xFFD4AF37),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Активные комнаты',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4,),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFD4AF37).withOpacity(0.3),),
                        ),
                        child: Text(
                          '${rooms.length}',
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final room = rooms[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: RoomCard(
                            room: room,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (room.status == 'active' &&
                                  room.isCurrentUserPlayer) {
                                context.push(
                                  Routes.gameSessionPath(room.id,
                                      title: room.name,),
                                );
                              } else {
                                context.push(Routes.waitingRoomPath(room.id));
                              }
                            },
                          ),
                        ),
                      );
                    },
                    childCount: rooms.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildCreatingView() => Center(
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
                    Icons.add,
                    color: Color(0xFFD4AF37),
                    size: 28,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Создание комнаты...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _buildErrorView(String message) => CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverFillRemaining(
            child: ErrorView(
              message: message,
              onRetry: _loadRooms,
            ),
          ),
        ],
      );

  Widget _buildSliverAppBar() => SliverAppBar(
        expandedHeight: 242,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push(Routes.roomCreate);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFFD4AF37)),
                    SizedBox(width: 4),
                    Text(
                      'Создать',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A3E),
                  Color(0xFF0D0D1A),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _StarFieldPainter()),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2A2A4A),
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sports_esports_outlined,
                            color: Color(0xFFD4AF37),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Игровое лобби',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Присоединяйтесь к приключению',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                  Icons.meeting_room_outlined,
                  size: 56,
                  color: Color(0xFF3A3A5E),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Нет активных комнат',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Нажмите «Создать» чтобы начать\nновое приключение',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);

    final positions = [
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.1),
      Offset(size.width * 0.7, size.height * 0.15),
      Offset(size.width * 0.9, size.height * 0.3),
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.85, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.05),
    ];

    for (final pos in positions) {
      canvas.drawCircle(pos, 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
