import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../bloc/scenario_bloc.dart';
import '../../bloc/scenario_event.dart';
import '../../bloc/scenario_state.dart';

class VersionHistorySheet extends StatefulWidget {

  const VersionHistorySheet({
    required this.scenarioId, super.key,
    this.onVersionRestored,
  });
  final String scenarioId;
  final VoidCallback? onVersionRestored;

  @override
  State<VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends State<VersionHistorySheet> {
  late final ScenarioBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ScenarioBloc>()
      ..add(ScenarioEvent.loadVersionHistory(scenarioId: widget.scenarioId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _restoreVersion(String versionId) {
    final sheetContext = context; // Save the sheet context

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Восстановить версию?'),
        content: const Text(
          'Это создаст новую версию на основе выбранной. '
          'Текущая версия сохранится в истории.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              // Close dialog first
              Navigator.of(dialogContext).pop();

              // Close bottom sheet using the saved sheet context
              Navigator.of(sheetContext).pop();

              // Now restore the version and reload
              _bloc.add(
                ScenarioEvent.restoreVersion(
                  scenarioId: widget.scenarioId,
                  versionId: versionId,
                ),
              );

              // Call the callback to reload scenario on main page
              widget.onVersionRestored?.call();
            },
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider<ScenarioBloc>.value(
      value: _bloc,
      child: DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 12),
                    const Text(
                      'История версий',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: BlocBuilder<ScenarioBloc, ScenarioState>(
                  builder: (context, state) {
                    if (state is ScenarioLoading) {
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: 5,
                        itemBuilder: (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LoadingSkeleton(height: 80),
                        ),
                      );
                    }

                    if (state is! ScenarioVersionHistory) {
                      return const Center(
                        child: Text('Не удалось загрузить историю версий'),
                      );
                    }

                    final versions = state.versions;

                    if (versions.isEmpty) {
                      return const Center(
                        child: Text('История версий пуста'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: versions.length,
                      itemBuilder: (context, index) {
                        final version = versions[index];
                        final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
                        final isLatest = index == 0;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isLatest
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                              child: Text(
                                'v${version.version}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              isLatest ? 'Текущая версия' : 'Версия ${version.version}',
                              style: TextStyle(
                                fontWeight:
                                    isLatest ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  version.userPrompt,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormat.format(version.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: !isLatest
                                ? IconButton(
                                    icon: const Icon(Icons.restore),
                                    tooltip: 'Восстановить',
                                    onPressed: () => _restoreVersion(version.id),
                                  )
                                : const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
