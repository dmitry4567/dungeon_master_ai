import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../scenario/bloc/scenario_bloc.dart';
import '../../scenario/bloc/scenario_event.dart';
import '../../scenario/bloc/scenario_state.dart';
import '../../scenario/models/scenario.dart';
import '../bloc/lobby_bloc.dart';
import '../bloc/lobby_event.dart';
import '../bloc/lobby_state.dart';

class RoomCreatePage extends StatefulWidget {
  const RoomCreatePage({super.key});

  @override
  State<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends State<RoomCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _maxPlayers = 5;
  bool _isSinglePlayer = false;
  Scenario? _selectedScenario;

  @override
  void initState() {
    super.initState();
    context.read<ScenarioBloc>().add(
          const ScenarioEvent.loadScenarios(status: 'published'),
        );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createRoom() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedScenario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите сценарий')),
      );
      return;
    }

    final versionId = _selectedScenario!.currentVersionId;
    if (versionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У сценария нет опубликованной версии')),
      );
      return;
    }

    context.read<LobbyBloc>().add(
          LobbyEvent.createRoom(
            name: _nameController.text.trim(),
            scenarioVersionId: versionId,
            maxPlayers: _isSinglePlayer ? 1 : _maxPlayers,
          ),
        );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Создать комнату'),
        ),
        body: BlocListener<LobbyBloc, LobbyState>(
          listener: (context, state) {
            state.whenOrNull(
              roomDetail: (room, _) {
                // Если одиночная игра, сразу стартуем
                if (_isSinglePlayer) {
                  context.read<LobbyBloc>().add(
                        LobbyEvent.startGame(roomId: room.id),
                      );
                } else {
                  context.pushReplacement(Routes.waitingRoomPath(room.id));
                }
              },
              gameStarting: (room, session) {
                // Переход в игровую сессию после автостарта
                context.pushReplacement(
                  Routes.gameSessionPath(room.id, title: room.name),
                );
              },
              error: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
            );
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Room name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название комнаты',
                      hintText: 'Введите название',
                      prefixIcon: Icon(Icons.meeting_room),
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 100,
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Минимум 3 символа';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Single player mode switch
                  Card(
                    child: SwitchListTile(
                      title: const Text('Одиночная игра'),
                      subtitle: const Text(
                        'Начать игру сразу, без других игроков',
                      ),
                      value: _isSinglePlayer,
                      onChanged: (value) {
                        setState(() {
                          _isSinglePlayer = value;
                          if (!value && _maxPlayers == 1) {
                            _maxPlayers = 2;
                          }
                        });
                      },
                      secondary: Icon(
                        _isSinglePlayer ? Icons.person : Icons.group,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Max players slider (hidden in single player mode)
                  if (!_isSinglePlayer) ...[
                    Text(
                      'Максимум игроков: $_maxPlayers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: _maxPlayers.toDouble(),
                      min: 2,
                      max: 5,
                      divisions: 3,
                      label: _maxPlayers.toString(),
                      onChanged: (value) {
                        setState(() => _maxPlayers = value.round());
                      },
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 8),

                  // Scenario selector
                  Text(
                    'Сценарий',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  BlocBuilder<ScenarioBloc, ScenarioState>(
                    builder: (context, state) => state.when(
                      initial: () => const Text('Загрузка сценариев...'),
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      loaded: (scenarios) {
                        if (scenarios.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Нет доступных сценариев. Создайте сценарий в разделе "Сценарии".',
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: scenarios.map((scenario) {
                            final isSelected =
                                _selectedScenario?.id == scenario.id;
                            return Card(
                              color: isSelected
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.15)
                                  : null,
                              child: ListTile(
                                leading: Icon(
                                  Icons.book,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                                title: Text(scenario.title),
                                subtitle: Text(scenario.status),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() => _selectedScenario = scenario);
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                      generating: (_) =>
                          const Center(child: CircularProgressIndicator()),
                      scenarioDetail: (_) => const SizedBox.shrink(),
                      versionHistory: (_, __) => const SizedBox.shrink(),
                      error: (message) => Text('Ошибка: $message'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Create button
                  BlocBuilder<LobbyBloc, LobbyState>(
                    builder: (context, state) {
                      final isCreating =
                          state.whenOrNull(creating: () => true) ?? false;
                      final isStarting =
                          state.whenOrNull(gameStarting: (_, __) => true) ??
                              false;
                      final isLoading = isCreating || isStarting;

                      String buttonText;
                      if (isStarting) {
                        buttonText = 'Запуск игры...';
                      } else if (isCreating) {
                        buttonText = 'Создание...';
                      } else if (_isSinglePlayer) {
                        buttonText = 'Начать игру';
                      } else {
                        buttonText = 'Создать комнату';
                      }

                      return ElevatedButton.icon(
                        onPressed: isLoading ? null : _createRoom,
                        icon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _isSinglePlayer
                                    ? Icons.play_arrow
                                    : Icons.add,
                              ),
                        label: Text(buttonText),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
