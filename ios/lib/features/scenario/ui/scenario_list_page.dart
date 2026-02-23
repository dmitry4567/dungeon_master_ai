import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/scenario_bloc.dart';
import '../bloc/scenario_event.dart';
import '../bloc/scenario_state.dart';
import 'widgets/scenario_card.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/error_view.dart';

class ScenarioListPage extends StatefulWidget {
  const ScenarioListPage({super.key});

  @override
  State<ScenarioListPage> createState() => _ScenarioListPageState();
}

class _ScenarioListPageState extends State<ScenarioListPage> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  void _loadScenarios() {
    context.read<ScenarioBloc>().add(
          ScenarioEvent.loadScenarios(status: _statusFilter),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сценарии'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _statusFilter = value == 'all' ? null : value;
              });
              _loadScenarios();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Все'),
              ),
              const PopupMenuItem(
                value: 'draft',
                child: Text('Черновики'),
              ),
              const PopupMenuItem(
                value: 'published',
                child: Text('Опубликованные'),
              ),
              const PopupMenuItem(
                value: 'archived',
                child: Text('Архивные'),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<ScenarioBloc, ScenarioState>(
        builder: (context, state) {
          return state.when(
            initial: () => const Center(
              child: Text('Создайте свой первый сценарий'),
            ),
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LoadingSkeleton(height: 120),
              ),
            ),
            loaded: (scenarios) {
              if (scenarios.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'У вас нет сценариев',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Нажмите + чтобы создать новый',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _loadScenarios(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scenarios.length,
                  itemBuilder: (context, index) {
                    final scenario = scenarios[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ScenarioCard(
                        scenario: scenario,
                        onTap: () => context.push('/scenarios/${scenario.id}'),
                      ),
                    );
                  },
                ),
              );
            },
            generating: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
            scenarioDetail: (_) => const SizedBox.shrink(),
            versionHistory: (_, __) => const SizedBox.shrink(),
            error: (message) => ErrorView(
              message: message,
              onRetry: _loadScenarios,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scenarios/builder'),
        icon: const Icon(Icons.add),
        label: const Text('Создать'),
      ),
    );
  }
}
