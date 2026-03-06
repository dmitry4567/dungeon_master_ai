import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/scenario_bloc.dart';
import '../bloc/scenario_event.dart';
import '../bloc/scenario_state.dart';

class ScenarioBuilderPage extends StatefulWidget {
  const ScenarioBuilderPage({
    super.key,
    this.scenarioId,
  });

  final String? scenarioId;

  @override
  State<ScenarioBuilderPage> createState() => _ScenarioBuilderPageState();
}

class _ScenarioBuilderPageState extends State<ScenarioBuilderPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isRefining = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isRefining = widget.scenarioId != null;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();

    final description = _descriptionController.text.trim();

    if (_isRefining) {
      context.read<ScenarioBloc>().add(
            ScenarioEvent.refineScenario(
              id: widget.scenarioId!,
              prompt: description,
            ),
          );
    } else {
      context.read<ScenarioBloc>().add(
            ScenarioEvent.createScenario(description: description),
          );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: BlocConsumer<ScenarioBloc, ScenarioState>(
            listener: (context, state) {
              state.maybeWhen(
                scenarioDetail: (scenario) {
                  context.go('/scenarios/${scenario.id}');
                },
                error: (message) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: const Color(0xFF8B3333),
                    ),
                  );
                },
                orElse: () {},
              );
            },
            builder: (context, state) {
              final isGenerating = state is ScenarioGenerating;

              return CustomScrollView(
                slivers: [
                  _buildAppBar(context),
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
                              _buildHeader(context),
                              const SizedBox(height: 24),
                              _buildDescriptionField(context, isGenerating),
                              const SizedBox(height: 24),
                              if (isGenerating)
                                _buildGeneratingState(context)
                              else ...[
                                _buildSubmitButton(context),
                                const SizedBox(height: 16),
                                if (!_isRefining) _buildTipsCard(context),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

  Widget _buildAppBar(BuildContext context) => SliverAppBar(
        expandedHeight: 214,
        pinned: true,
        // backgroundColor: Colors.transparent,
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
                            Icons.auto_stories,
                            color: Color(0xFFD4AF37),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isRefining
                              ? 'Доработка сценария'
                              : 'Создать сценарий',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRefining
                              ? 'Внесите изменения в существующую историю'
                              : 'Создайте уникальную историю для D&D',
                          style: const TextStyle(
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

  Widget _buildHeader(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFD4AF37).withOpacity(0.15),
              const Color(0xFFD4AF37).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A4A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              ),
              child: const Icon(
                Icons.menu_book,
                color: Color(0xFFD4AF37),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRefining ? 'Улучшение сценария' : 'Новый сценарий',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRefining
                        ? 'Добавьте новые детали или измените существующие'
                        : 'AI создаст полноценный сценарий с актами, NPC и локациями',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDescriptionField(BuildContext context, bool isGenerating) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1F),
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
                    Icons.edit_note,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isRefining ? 'Описание изменений' : 'Описание сценария',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${_descriptionController.text.length}/${_isRefining ? 1000 : 2000}',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A14).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _descriptionController.text.isNotEmpty
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFF2A2A4E),
                  width: 1.5,
                ),
              ),
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 10,
                maxLength: _isRefining ? 1000 : 2000,
                enabled: !isGenerating,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: _isRefining
                      ? 'Например: Добавь больше драматических моментов в первый акт, увеличь количество боевых сцен...'
                      : 'Например: Средневековая фэнтези история о группе героев, которые должны остановить восстание нежити в королевстве. Сценарий рассчитан на 3-5 игроков начального уровня...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '',
                  disabledBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Описание не может быть пустым';
                  }
                  if (value.trim().length < 10) {
                    return 'Опишите подробнее (минимум 10 символов)';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildGeneratingState(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
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
                    Icons.auto_stories,
                    color: Color(0xFFD4AF37),
                    size: 28,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '🎲 AI создаёт ваш сценарий...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Это может занять до минуты',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF2A2A4E),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              minHeight: 4,
            ),
          ],
        ),
      );

  Widget _buildSubmitButton(BuildContext context) {
    final isCreating = !_isRefining;

    return InkWell(
      onTap: _submit,
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
            Icon(
              isCreating ? Icons.auto_awesome : Icons.auto_fix_high,
              size: 24,
              color: const Color(0xFFD4AF37),
            ),
            const SizedBox(width: 6),
            Text(
              _isRefining ? 'Доработать' : 'Создать сценарий',
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
  }

  Widget _buildTipsCard(BuildContext context) => Container(
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
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFFD4AF37),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Советы для лучшего сценария',
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
            _buildTipItem(
              context,
              icon: Icons.location_city_outlined,
              text: 'Укажите сеттинг (фэнтези, хоррор, научная фантастика)',
            ),
            _buildTipItem(
              context,
              icon: Icons.flag_outlined,
              text: 'Опишите основной конфликт или цель героев',
            ),
            _buildTipItem(
              context,
              icon: Icons.people_outline,
              text: 'Упомяните количество игроков и их уровень',
            ),
            _buildTipItem(
              context,
              icon: Icons.trending_up_outlined,
              text: 'Задайте сложность (новички, опытные игроки)',
            ),
            _buildTipItem(
              context,
              icon: Icons.auto_awesome_outlined,
              text: 'Добавьте уникальные элементы или неожиданные повороты',
            ),
          ],
        ),
      );

  Widget _buildTipItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                icon,
                size: 14,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
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
