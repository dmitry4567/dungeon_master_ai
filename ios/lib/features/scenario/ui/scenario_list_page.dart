import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/scenario_bloc.dart';
import '../bloc/scenario_event.dart';
import '../bloc/scenario_state.dart';
import '../models/scenario.dart';
import 'widgets/scenario_card.dart';

class ScenarioListPage extends StatefulWidget {
  const ScenarioListPage({super.key});

  @override
  State<ScenarioListPage> createState() => _ScenarioListPageState();
}

class _ScenarioListPageState extends State<ScenarioListPage> {
  String? _statusFilter;

  static const _filters = [
    ('all', 'Все'),
    ('draft', 'Черновики'),
    ('published', 'Опубликованные'),
    ('archived', 'Архивные'),
  ];

  void _loadScenarios() {
    context.read<ScenarioBloc>().add(
          const LoadScenariosEvent(status: null),
        );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: BlocBuilder<ScenarioBloc, ScenarioState>(
          builder: (context, state) {
            if (state is ScenarioInitial) {
              return _buildScrollView(context,
                child: const SliverFillRemaining(child: _EmptyView()),);
            }
            if (state is ScenarioLoading) {
              return _buildScrollView(context, isLoading: true);
            }
            if (state is ScenarioLoaded) {
              return RefreshIndicator(
                color: const Color(0xFFD4AF37),
                backgroundColor: const Color(0xFF1A1A2E),
                onRefresh: () async => _loadScenarios(),
                child: _buildScrollView(
                  context,
                  scenarios: state.scenarios,
                ),
              );
            }
            if (state is ScenarioGenerating) {
              return _buildScrollView(
                context,
                child: const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFD4AF37)),
                        SizedBox(height: 16),
                        Text(
                          'Генерируется сценарий...',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (state is ScenarioDetail) {
              return _buildScrollView(context);
            }
            if (state is ScenarioVersionHistory) {
              return _buildScrollView(context);
            }
            if (state is ScenarioError) {
              return _buildScrollView(
                context,
                child: SliverFillRemaining(
                    child: _ErrorView(message: state.message, onRetry: _loadScenarios),),
              );
            }
            return _buildScrollView(context);
          },
        ),
      );

  Widget _buildScrollView(
    BuildContext context, {
    List<dynamic>? scenarios,
    bool isLoading = false,
    Widget? child,
  }) =>
      CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          _buildFilterRow(context),
          if (isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _SkeletonCard(),
                  ),
                  childCount: 3,
                ),
              ),
            )
          else if (scenarios != null && scenarios.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories,
                        color: Color(0xFFD4AF37), size: 20,),
                    const SizedBox(width: 8),
                    Text(
                      'Мои сценарии',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
                        '${scenarios.length}',
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ScenarioCard(
                      scenario: scenarios[index] as Scenario,
                      onTap: () =>
                          context.push('/scenarios/${scenarios[index].id}'),
                    ),
                  ),
                  childCount: scenarios.length,
                ),
              ),
            ),
          ] else if (scenarios != null && scenarios.isEmpty)
            const SliverFillRemaining(child: _EmptyView())
          else if (child != null)
            child,
        ],
      );

  Widget _buildSliverAppBar(BuildContext context) => SliverAppBar(
        expandedHeight: 242,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => context.push('/scenarios/builder'),
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
                colors: [Color(0xFF1A1A3E), Color(0xFF0D0D1A)],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                    child: CustomPaint(painter: _StarFieldPainter()),),
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
                                color: const Color(0xFFD4AF37), width: 2.5,),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_stories,
                            color: Color(0xFFD4AF37),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Сценарии',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Истории для ваших приключений',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
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

  Widget _buildFilterRow(BuildContext context) => SliverToBoxAdapter(
        child: SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: _filters.map((f) {
              final isActive = (_statusFilter == null && f.$1 == 'all') ||
                  _statusFilter == f.$1;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _statusFilter = f.$1 == 'all' ? null : f.$1;
                    });
                    _loadScenarios();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFD4AF37).withOpacity(0.15)
                          : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFD4AF37).withOpacity(0.5)
                            : const Color(0xFF2A2A4E),
                      ),
                    ),
                    child: Text(
                      f.$2,
                      style: TextStyle(
                        color:
                            isActive ? const Color(0xFFD4AF37) : Colors.white54,
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
              const Icon(Icons.book_outlined,
                  size: 56, color: Color(0xFF3A3A5E),),
              const SizedBox(height: 16),
              const Text(
                'Нет сценариев',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Создайте свой первый сценарий\nдля незабываемого приключения',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 13,),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: Color(0xFF8B3333),),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                ),
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
      );
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
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
