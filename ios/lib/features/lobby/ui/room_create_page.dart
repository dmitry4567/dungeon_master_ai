import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _RoomCreateViewState extends State<_RoomCreateView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _maxPlayers = 5;
  bool _isSinglePlayer = false;
  Scenario? _selectedScenario;
  Character? _selectedCharacter;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    context.read<ScenarioBloc>().add(
          const ScenarioEvent.loadScenarios(status: 'published'),
        );
    context.read<CharacterBloc>().add(const CharacterEvent.loadCharacters());

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
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _createRoom() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedScenario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите сценарий'),
          backgroundColor: Color(0xFF8B3333),
        ),
      );
      return;
    }

    if (_isSinglePlayer && _selectedCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите персонажа для одиночной игры'),
          backgroundColor: Color(0xFF8B3333),
        ),
      );
      return;
    }

    final versionId = _selectedScenario!.currentVersionId;
    if (versionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У сценария нет опубликованной версии'),
          backgroundColor: Color(0xFF8B3333),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

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
        backgroundColor: const Color(0xFF0D0D1A),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: BlocListener<LobbyBloc, LobbyState>(
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
                    SnackBar(
                      content: Text(message),
                      backgroundColor: const Color(0xFF8B3333),
                    ),
                  );
                },
              );
            },
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildNameField(),
                            const SizedBox(height: 20),
                            _buildGameModeCard(),
                            const SizedBox(height: 20),
                            if (!_isSinglePlayer) ...[
                              _buildPlayersSlider(),
                              const SizedBox(height: 20),
                            ] else ...[
                              _buildCharacterSelector(),
                              const SizedBox(height: 20),
                            ],
                            _buildScenarioSelector(),
                            const SizedBox(height: 32),
                            _buildCreateButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSliverAppBar() => SliverAppBar(
        expandedHeight: 180,
        pinned: true,
        backgroundColor: const Color(0xFF0D0D1A),
        surfaceTintColor: Colors.transparent,
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
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
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
                            Icons.add,
                            color: Color(0xFFD4AF37),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Создать комнату',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Начните новое приключение',
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

  Widget _buildNameField() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1A2E),
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
                    Icons.meeting_room,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Название комнаты',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _nameController.text.isNotEmpty
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFF2A2A4E),
                  width: 1.5,
                ),
              ),
              child: TextFormField(
                controller: _nameController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                    hintText: 'Введите название комнаты...',
                    hintStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    counterText: '',
                    disabledBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    fillColor: Colors.transparent,),
                maxLength: 100,
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Минимум 3 символа';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildGameModeCard() => Container(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isSinglePlayer ? Icons.person : Icons.group,
                    color: const Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Режим игры',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _GameModeOption(
                    icon: Icons.person,
                    label: 'Одиночная',
                    isSelected: _isSinglePlayer,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isSinglePlayer = true;
                        if (_maxPlayers == 1) _maxPlayers = 2;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GameModeOption(
                    icon: Icons.group,
                    label: 'Компания',
                    isSelected: !_isSinglePlayer,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isSinglePlayer = false);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildPlayersSlider() => Container(
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
                    color: const Color(0xFF52B788).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Color(0xFF52B788),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Количество игроков',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF52B788).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF52B788).withOpacity(0.4),),
                  ),
                  child: Text(
                    '$_maxPlayers',
                    style: const TextStyle(
                      color: Color(0xFF52B788),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF52B788),
                inactiveTrackColor: const Color(0xFF2A2A4E),
                thumbColor: const Color(0xFF52B788),
                overlayColor: const Color(0xFF52B788).withOpacity(0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 8,
                ),
                value: _maxPlayers.toDouble(),
                min: 2,
                max: 5,
                divisions: 3,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _maxPlayers = value.round());
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildCharacterSelector() => Container(
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
                    Icons.shield,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Выберите персонажа',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<CharacterBloc, CharacterState>(
              builder: (context, state) => state.when(
                initial: () => const Text('Загрузка...',
                    style: TextStyle(color: Colors.white54),),
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),),
                loaded: (characters) {
                  if (characters.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A4E)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFF4A261), size: 20,),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Нет персонажей. Создайте персонажа в разделе "Персонажи".',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13,),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: characters.map((character) {
                      final isSelected = _selectedCharacter?.id == character.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CharacterOption(
                          character: character,
                          isSelected: isSelected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCharacter = character);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
                error: (message, _) => Text('Ошибка: $message',
                    style: const TextStyle(color: Color(0xFFE76F51)),),
                creating: (_) => const SizedBox.shrink(),
                submitting: (_) => const SizedBox.shrink(),
                created: (_) => const SizedBox.shrink(),
                deleted: (_) => const SizedBox.shrink(),
                detail: (_) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );

  Widget _buildScenarioSelector() => Container(
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
                    Icons.auto_stories,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Выберите сценарий',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<ScenarioBloc, ScenarioState>(
              builder: (context, state) => state.when(
                initial: () => const Text('Загрузка...',
                    style: TextStyle(color: Colors.white54),),
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),),
                loaded: (scenarios) {
                  if (scenarios.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A4E)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFF4A261), size: 20,),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Нет сценариев. Создайте сценарий в разделе "Сценарии".',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13,),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: scenarios.map((scenario) {
                      final isSelected = _selectedScenario?.id == scenario.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ScenarioOption(
                          scenario: scenario,
                          isSelected: isSelected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedScenario = scenario);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
                generating: (_) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),),
                scenarioDetail: (_) => const SizedBox.shrink(),
                versionHistory: (_, __) => const SizedBox.shrink(),
                error: (message) => Text('Ошибка: $message',
                    style: const TextStyle(color: Color(0xFFE76F51)),),
              ),
            ),
          ],
        ),
      );

  Widget _buildCreateButton() =>
      BlocBuilder<LobbyBloc, LobbyState>(builder: (context, state) {
        final isCreating = state.whenOrNull(creating: () => true) ?? false;
        final isStarting =
            state.whenOrNull(gameStarting: (_, __) => true) ?? false;
        final isLoading = isCreating || isStarting;

        String buttonText;
        IconData buttonIcon;
        if (isStarting) {
          buttonText = 'Запуск...';
          buttonIcon = Icons.rocket_launch;
        } else if (isCreating) {
          buttonText = 'Создание...';
          buttonIcon = Icons.hourglass_empty;
        } else if (_isSinglePlayer) {
          buttonText = 'Начать игру';
          buttonIcon = Icons.play_arrow;
        } else {
          buttonText = 'Создать комнату';
          buttonIcon = Icons.add;
        }

        return InkWell(
          onTap: isLoading ? null : _createRoom,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFD4AF37).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                    ),
                  )
                else
                  Icon(
                    buttonIcon,
                    size: 24,
                    color: const Color(0xFFD4AF37),
                  ),
                if (!isLoading) const SizedBox(width: 6),
                if (!isLoading)
                  Text(
                    buttonText,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        );
      },);
}

class _GameModeOption extends StatelessWidget {
  const _GameModeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD4AF37).withOpacity(0.15)
                : const Color(0xFF0F0F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFF2A2A4E),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFFD4AF37)
                    : const Color(0xFF5A5A7E),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFF5A5A7E),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CharacterOption extends StatelessWidget {
  const _CharacterOption({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  final Character character;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD4AF37).withOpacity(0.1)
                : const Color(0xFF0F0F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFF2A2A4E),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFF3A3A5E),
                      width: isSelected ? 2 : 1,),
                ),
                child: const Icon(Icons.shield,
                    color: Color(0xFFD4AF37), size: 22,),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${character.race} • ${character.characterClass} • Ур. ${character.level}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: Color(0xFFD4AF37), size: 22,)
              else
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF3A3A5E), width: 2),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _ScenarioOption extends StatelessWidget {
  const _ScenarioOption({
    required this.scenario,
    required this.isSelected,
    required this.onTap,
  });

  final Scenario scenario;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD4AF37).withOpacity(0.1)
                : const Color(0xFF0F0F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFF2A2A4E),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A4A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFF3A3A5E),
                      width: isSelected ? 2 : 1,),
                ),
                child: const Icon(Icons.auto_stories,
                    color: Color(0xFFD4AF37), size: 22,),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2,),
                      decoration: BoxDecoration(
                        color: const Color(0xFF52B788).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFF52B788).withOpacity(0.4),),
                      ),
                      child: Text(
                        scenario.status == 'published'
                            ? 'Опубликован'
                            : scenario.status,
                        style: const TextStyle(
                          color: Color(0xFF52B788),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: Color(0xFFD4AF37), size: 22,)
              else
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF3A3A5E), width: 2),
                  ),
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
