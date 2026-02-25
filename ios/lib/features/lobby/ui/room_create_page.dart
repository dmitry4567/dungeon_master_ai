import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/routes.dart';
import '../../character/bloc/character_bloc.dart';
import '../../character/bloc/character_event.dart';
import '../../character/bloc/character_state.dart';
import '../../character/models/character.dart';
import '../../scenario/bloc/scenario_bloc.dart';
import '../../scenario/bloc/scenario_event.dart';
import '../../scenario/bloc/scenario_state.dart';
import '../../scenario/models/scenario.dart';
import '../bloc/lobby_bloc.dart';
import '../bloc/lobby_event.dart';
import '../bloc/lobby_state.dart';

class RoomCreatePage extends StatelessWidget {
  const RoomCreatePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (context) => getIt<CharacterBloc>(),
      child: const _RoomCreateView(),
    );
}

class _RoomCreateView extends StatefulWidget {
  const _RoomCreateView();

  @override
  State<_RoomCreateView> createState() => _RoomCreateViewState();
}

class _RoomCreateViewState extends State<_RoomCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _maxPlayers = 5;
  bool _isSinglePlayer = false;
  Scenario? _selectedScenario;
  Character? _selectedCharacter;

  @override
  void initState() {
    super.initState();
    context.read<ScenarioBloc>().add(
          const ScenarioEvent.loadScenarios(status: 'published'),
        );
    context.read<CharacterBloc>().add(const CharacterEvent.loadCharacters());
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

    if (_isSinglePlayer && _selectedCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите персонажа для одиночной игры')),
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
            characterId: _isSinglePlayer ? _selectedCharacter!.id : null,
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
                if (_isSinglePlayer) {
                  context.read<LobbyBloc>().add(
                        LobbyEvent.startGame(roomId: room.id),
                      );
                } else {
                  context.pushReplacement(Routes.waitingRoomPath(room.id));
                }
              },
              gameStarting: (room, session) {
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
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Персонаж',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildCharacterSelector(),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Сценарий',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildScenarioSelector(),
                  const SizedBox(height: 32),
                  _buildCreateButton(),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildCharacterSelector() => BlocBuilder<CharacterBloc, CharacterState>(
      builder: (context, state) => state.when(
        initial: () => const Text('Загрузка персонажей...'),
        loading: () => const Center(child: CircularProgressIndicator()),
        loaded: (characters) {
          if (characters.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Нет доступных персонажей. Создайте персонажа в разделе "Персонажи".',
                ),
              ),
            );
          }
          return Column(
            children: characters.map((character) {
              final isSelected = _selectedCharacter?.id == character.id;
              return Card(
                color: isSelected
                    ? Theme.of(context).primaryColor.withAlpha(30)
                    : null,
                child: ListTile(
                  leading: Icon(
                    Icons.person_outline,
                    color:
                        isSelected ? Theme.of(context).primaryColor : null,
                  ),
                  title: Text(character.name),
                  subtitle: Text(
                    '${character.race} ${character.characterClass}, Lvl ${character.level}',
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedCharacter = character);
                  },
                ),
              );
            }).toList(),
          );
        },
        error: (message, _) => Text('Ошибка: $message'),
        creating: (_) => const SizedBox.shrink(),
        submitting: (_) => const SizedBox.shrink(),
        created: (_) => const SizedBox.shrink(),
        deleted: (_) => const SizedBox.shrink(),
        detail: (_) => const SizedBox.shrink(),
      ),
    );

  Widget _buildScenarioSelector() => BlocBuilder<ScenarioBloc, ScenarioState>(
      builder: (context, state) => state.when(
        initial: () => const Text('Загрузка сценариев...'),
        loading: () => const Center(child: CircularProgressIndicator()),
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
              final isSelected = _selectedScenario?.id == scenario.id;
              return Card(
                color: isSelected
                    ? Theme.of(context).primaryColor.withAlpha(30)
                    : null,
                child: ListTile(
                  leading: Icon(
                    Icons.book,
                    color:
                        isSelected ? Theme.of(context).primaryColor : null,
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
        generating: (_) => const Center(child: CircularProgressIndicator()),
        scenarioDetail: (_) => const SizedBox.shrink(),
        versionHistory: (_, __) => const SizedBox.shrink(),
        error: (message) => Text('Ошибка: $message'),
      ),
    );

  Widget _buildCreateButton() => BlocBuilder<LobbyBloc, LobbyState>(
      builder: (context, state) {
        final isCreating = state.whenOrNull(creating: () => true) ?? false;
        final isStarting =
            state.whenOrNull(gameStarting: (_, __) => true) ?? false;
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _isSinglePlayer ? Icons.play_arrow : Icons.add,
                ),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        );
      },
    );
}
