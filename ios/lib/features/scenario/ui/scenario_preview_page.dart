import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../bloc/scenario_bloc.dart';
import '../bloc/scenario_event.dart';
import '../bloc/scenario_state.dart';
import '../models/scenario.dart';
import 'widgets/act_expansion_tile.dart';
import 'widgets/npc_card.dart';
import 'widgets/version_history_sheet.dart';

class ScenarioPreviewPage extends StatefulWidget {

  const ScenarioPreviewPage({
    required this.scenarioId, super.key,
  });
  final String scenarioId;

  @override
  State<ScenarioPreviewPage> createState() => _ScenarioPreviewPageState();
}

class _ScenarioPreviewPageState extends State<ScenarioPreviewPage> {
  @override
  void initState() {
    super.initState();
    _loadScenario();
  }

  void _loadScenario() {
    context.read<ScenarioBloc>().add(
          ScenarioEvent.loadScenario(id: widget.scenarioId),
        );
  }

  void _showVersionHistory(Scenario scenario) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => VersionHistorySheet(
        scenarioId: scenario.id,
        onVersionRestored: () {
          // Reload the scenario after version is restored
          context.read<ScenarioBloc>().add(
                ScenarioEvent.loadScenario(id: scenario.id),
              );
        },
      ),
    );
  }

  void _refineScenario() {
    context.push('/scenarios/${widget.scenarioId}/refine');
  }

  void _publishScenario() {
    context.read<ScenarioBloc>().add(
          ScenarioEvent.publishScenario(scenarioId: widget.scenarioId),
        );
  }

  @override
  Widget build(BuildContext context) => BlocListener<ScenarioBloc, ScenarioState>(
      listener: (context, state) {
        if (state is ScenarioDetail && state.scenario.status == 'published') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сценарий опубликован'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is ScenarioError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Превью сценария'),
        actions: [
          BlocBuilder<ScenarioBloc, ScenarioState>(
            builder: (context, state) {
              if (state is! ScenarioDetail) return const SizedBox.shrink();

              final isDraft = state.scenario.status == 'draft';
              return PopupMenuButton(
                itemBuilder: (context) => [
                  if (isDraft)
                    const PopupMenuItem(
                      value: 'publish',
                      child: Row(
                        children: [
                          Icon(Icons.publish),
                          SizedBox(width: 8),
                          Text('Опубликовать'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'refine',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Доработать'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        Icon(Icons.history),
                        SizedBox(width: 8),
                        Text('История версий'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'publish') {
                    _publishScenario();
                  } else if (value == 'refine') {
                    _refineScenario();
                  } else if (value == 'history') {
                    _showVersionHistory(state.scenario);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ScenarioBloc, ScenarioState>(
        builder: (context, state) {
          if (state is ScenarioLoading) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                LoadingSkeleton(height: 120),
                SizedBox(height: 16),
                LoadingSkeleton(height: 200),
                SizedBox(height: 16),
                LoadingSkeleton(height: 150),
              ],
            );
          }

          if (state is ScenarioError) {
            return ErrorView(
              message: state.message,
              onRetry: _loadScenario,
            );
          }

          if (state is! ScenarioDetail) {
            return const Center(child: Text('Сценарий не найден'));
          }

          final scenario = state.scenario;
          final content = scenario.currentVersion?.content;

          if (content == null) {
            return const Center(
              child: Text('Контент сценария недоступен'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  scenario.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(content.difficulty),
                      avatar: const Icon(Icons.trending_up, size: 18),
                    ),
                    Chip(
                      label: Text(content.tone),
                      avatar: const Icon(Icons.palette, size: 18),
                    ),
                    Chip(
                      label: Text(
                          '${content.playersMin}-${content.playersMax} игроков',),
                      avatar: const Icon(Icons.people, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // World Lore
                const _SectionHeader(
                  icon: Icons.public,
                  title: 'История мира',
                ),
                const SizedBox(height: 8),
                Text(
                  content.worldLore,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 24),

                // Acts
                _SectionHeader(
                  icon: Icons.theater_comedy,
                  title: 'Акты (${content.acts.length})',
                ),
                const SizedBox(height: 12),
                ...content.acts.map((act) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActExpansionTile(act: act),
                    ),),
                const SizedBox(height: 24),

                // NPCs
                _SectionHeader(
                  icon: Icons.person,
                  title: 'Персонажи (${content.npcs.length})',
                ),
                const SizedBox(height: 12),
                ...content.npcs.map((npc) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NpcCard(npc: npc),
                    ),),
                const SizedBox(height: 24),

                // Locations
                _SectionHeader(
                  icon: Icons.location_on,
                  title: 'Локации (${content.locations.length})',
                ),
                const SizedBox(height: 12),
                ...content.locations.map((location) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.castle),
                        title: Text(location.name),
                        subtitle: Text(location.atmosphere),
                        trailing: Text(
                          '${location.rooms.length} комнат',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),),
              ],
            ),
          );
        },
      ),
      ),
    );
}

class _SectionHeader extends StatelessWidget {

  const _SectionHeader({
    required this.icon,
    required this.title,
  });
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
}
