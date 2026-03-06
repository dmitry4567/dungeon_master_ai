import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../bloc/scenario_bloc.dart';
import '../bloc/scenario_event.dart';
import '../bloc/scenario_state.dart';
import '../models/scenario.dart';
import '../models/scenario_content.dart';
import 'widgets/act_expansion_tile.dart';
import 'widgets/npc_card.dart';
import 'widgets/version_history_sheet.dart';

class ScenarioPreviewPage extends StatefulWidget {
  const ScenarioPreviewPage({
    required this.scenarioId,
    super.key,
  });

  final String scenarioId;

  @override
  State<ScenarioPreviewPage> createState() => _ScenarioPreviewPageState();
}

class _ScenarioPreviewPageState extends State<ScenarioPreviewPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadScenario();

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

  void _loadScenario() {
    context.read<ScenarioBloc>().add(
          ScenarioEvent.loadScenario(id: widget.scenarioId),
        );
  }

  void _showVersionHistory(Scenario scenario) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (bottomSheetContext) => VersionHistorySheet(
        scenarioId: scenario.id,
        onVersionRestored: () {
          context.read<ScenarioBloc>().add(
                ScenarioEvent.loadScenario(id: scenario.id),
              );
        },
      ),
    );
  }

  void _refineScenario() {
    HapticFeedback.selectionClick();
    context.push('/scenarios/${widget.scenarioId}/refine');
  }

  void _publishScenario() {
    HapticFeedback.mediumImpact();
    context.read<ScenarioBloc>().add(
          ScenarioEvent.publishScenario(scenarioId: widget.scenarioId),
        );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ScenarioBloc, ScenarioState>(
        listener: (context, state) {
          if (state is ScenarioDetail && state.scenario.status == 'published') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Сценарий опубликован'),
                backgroundColor: Color(0xFF52B788),
              ),
            );
          } else if (state is ScenarioError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF8B3333),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          body: BlocBuilder<ScenarioBloc, ScenarioState>(
            builder: (context, state) {
              if (state is ScenarioLoading) {
                return _buildLoadingView();
              }

              if (state is ScenarioError) {
                return _buildErrorView(state.message);
              }

              if (state is! ScenarioDetail) {
                return const Center(
                  child: Text('Сценарий не найден',
                      style: TextStyle(color: Colors.white54),),
                );
              }

              final scenario = state.scenario;
              final content = scenario.currentVersion?.content;

              if (content == null) {
                return const Center(
                  child: Text('Контент сценария недоступен',
                      style: TextStyle(color: Colors.white54),),
                );
              }

              return _buildContent(context, scenario, content);
            },
          ),
        ),
      );

  Widget _buildLoadingView() => CustomScrollView(
        slivers: [
          _buildSliverAppBar(null, null),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LoadingSkeleton(height: 100, borderRadius: 12),
                ),
                childCount: 5,
              ),
            ),
          ),
        ],
      );

  Widget _buildErrorView(String message) => CustomScrollView(
        slivers: [
          _buildSliverAppBar(null, null),
          SliverFillRemaining(
            child: ErrorView(
              message: message,
              onRetry: _loadScenario,
            ),
          ),
        ],
      );

  Widget _buildContent(
          BuildContext context, Scenario scenario, ScenarioContent content,) =>
      CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, scenario),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & Info Bar
                  _buildStatusBar(context, scenario, content),
                  const SizedBox(height: 16),

                  // World Lore
                  _buildWorldLoreSection(context, content),
                  const SizedBox(height: 20),

                  // Acts
                  _buildActsSection(context, content),
                  const SizedBox(height: 20),

                  // NPCs
                  _buildNpcsSection(context, content),
                  const SizedBox(height: 20),

                  // Locations
                  _buildLocationsSection(context, content),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _buildSliverAppBar(BuildContext? context, Scenario? scenario) =>
      SliverAppBar(
        expandedHeight: 244,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
        actions: [
          if (context != null && scenario != null)
            _buildActionsMenu(context, scenario),
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
                            Icons.auto_stories,
                            color: Color(0xFFD4AF37),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          scenario?.title ?? 'Загрузка...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scenario?.status == 'published'
                              ? 'Опубликованный сценарий'
                              : 'Черновик',
                          style: TextStyle(
                            color: scenario?.status == 'published'
                                ? const Color(0xFF52B788)
                                : const Color(0xFFF4A261),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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

  Widget _buildActionsMenu(BuildContext context, Scenario scenario) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.more_vert,
              color: Color(0xFFD4AF37),
              size: 20,
            ),
          ),
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: const Color(0xFF1A1A2E),
          itemBuilder: (context) {
            final items = <PopupMenuItem<String>>[];

            if (scenario.status == 'draft') {
              items.add(const PopupMenuItem<String>(
                value: 'publish',
                child: Row(
                  children: [
                    Icon(Icons.publish, color: Color(0xFF52B788), size: 20),
                    SizedBox(width: 12),
                    Text('Опубликовать', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),);
            }

            items.addAll(<PopupMenuItem<String>>[
              const PopupMenuItem<String>(
                value: 'refine',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Color(0xFFD4AF37), size: 20),
                    SizedBox(width: 12),
                    Text('Доработать', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Color(0xFF64B5F6), size: 20),
                    SizedBox(width: 12),
                    Text('История версий',
                        style: TextStyle(color: Colors.white),),
                  ],
                ),
              ),
            ]);

            return items;
          },
          onSelected: (value) {
            if (value == 'publish') {
              _publishScenario();
            } else if (value == 'refine') {
              _refineScenario();
            } else if (value == 'history') {
              _showVersionHistory(scenario);
            }
          },
        ),
      );

  Widget _buildStatusBar(
          BuildContext context, Scenario scenario, ScenarioContent content,) =>
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD4AF37).withOpacity(0.1),
              const Color(0xFFD4AF37).withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatBadge(
                    icon: Icons.trending_up,
                    label: content.difficulty,
                    color: const Color(0xFFE76F51),
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    icon: Icons.palette,
                    label: content.tone,
                    color: const Color(0xFF2A9D8F),
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    icon: Icons.people,
                    label: '${content.playersMin}–${content.playersMax}',
                    color: const Color(0xFF264653),
                    isPlayerCount: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMiniStat(
                  icon: Icons.theater_comedy,
                  value: '${content.acts.length}',
                  label: 'акта',
                ),
                const SizedBox(width: 20),
                _buildMiniStat(
                  icon: Icons.person,
                  value: '${content.npcs.length}',
                  label: 'NPC',
                ),
                const SizedBox(width: 20),
                _buildMiniStat(
                  icon: Icons.location_on,
                  value: '${content.locations.length}',
                  label: 'локаций',
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Color color,
    bool isPlayerCount = false,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              isPlayerCount ? '$label игр.' : label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
  }) =>
      Row(
        children: [
          Icon(icon, size: 34, color: const Color(0xFF5A5A7E)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _buildWorldLoreSection(
          BuildContext context, ScenarioContent content,) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.public,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'История мира',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content.worldLore,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      );

  Widget _buildActsSection(BuildContext context, ScenarioContent content) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.theater_comedy,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Акты (${content.acts.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...content.acts.map<Widget>(
            (act) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ActExpansionTile(act: act),
            ),
          ),
        ],
      );

  Widget _buildNpcsSection(BuildContext context, ScenarioContent content) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Персонажи (${content.npcs.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...content.npcs.map<Widget>(
            (npc) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: NpcCard(npc: npc),
            ),
          ),
        ],
      );

  Widget _buildLocationsSection(
          BuildContext context, ScenarioContent content,) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Локации (${content.locations.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...content.locations.map<Widget>((location) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildLocationCard(location),
              ),),
        ],
      );

  Widget _buildLocationCard(Location location) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A4A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              ),
              child: const Icon(
                Icons.castle,
                color: Color(0xFFD4AF37),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location.atmosphere,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
              ),
              child: Text(
                '${location.rooms.length}',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
