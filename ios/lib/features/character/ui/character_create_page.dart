import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/character_bloc.dart';
import '../bloc/character_event.dart';
import '../bloc/character_state.dart';
import 'widgets/ability_scores_editor.dart';
import 'widgets/class_selector.dart';
import 'widgets/race_selector.dart';

/// Страница создания персонажа
class CharacterCreatePage extends StatelessWidget {
  const CharacterCreatePage({super.key});

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: BlocConsumer<CharacterBloc, CharacterState>(
          listener: (context, state) {
            if (state is CharacterCreated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Персонаж "${state.character.name}" создан!'),
                  backgroundColor: const Color(0xFF52B788),
                ),
              );
              context.pop(true);
            } else if (state is CharacterError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: const Color(0xFF8B3333),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is! CharacterCreating && state is! CharacterSubmitting) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<CharacterBloc>().add(
                      const StartCreationEvent(),
                    );
              });
              return const Scaffold(
                backgroundColor: Color(0xFF0D0D1A),
                body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),),
              );
            }
        
            final form = state is CharacterCreating
                ? state.form
                : (state as CharacterSubmitting).form;
            final isSubmitting = state is CharacterSubmitting;
        
            return WillPopScope(
              onWillPop: () async {
                if (form.currentStep > 0) {
                  context.read<CharacterBloc>().add(
                        const PreviousStepEvent(),
                      );
                  return false;
                }
                return true;
              },
              child: Scaffold(
                backgroundColor: const Color(0xFF0D0D1A),
                body: Column(
                  children: [
                    _buildSliverAppBar(context, form),
                    Expanded(
                      child: Column(
                        children: [
                          // Контент шага
                          Expanded(
                            child: _StepContent(form: form),
                          ),
        
                          // Кнопки навигации
                          _NavigationButtons(
                            form: form,
                            isSubmitting: isSubmitting,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _buildSliverAppBar(BuildContext context, CharacterCreationForm form) =>
      Container(
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
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
        child: Column(
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFFD4AF37),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Создание персонажа',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        form.currentStepTitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    '${form.currentStep + 1}/${CharacterCreationForm.totalSteps}',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:
                    (form.currentStep + 1) / CharacterCreationForm.totalSteps,
                backgroundColor: const Color(0xFF2A2A4E),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                minHeight: 4,
              ),
            ),
            // Ошибки валидации
            if (form.validationErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE76F51).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE76F51).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFE76F51),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        form.validationErrors.join('\n'),
                        style: const TextStyle(
                          color: Color(0xFFE76F51),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}

class _StepContent extends StatelessWidget {
  const _StepContent({required this.form});

  final CharacterCreationForm form;

  @override
  Widget build(BuildContext context) => switch (form.currentStep) {
        CharacterCreationForm.classStep => ClassSelector(
            selectedClass: form.selectedClass,
            onSelect: (dndClass) {
              context.read<CharacterBloc>().add(
                    SelectClassEvent(selectedClass: dndClass),
                  );
            },
          ),
        CharacterCreationForm.raceStep => RaceSelector(
            selectedRace: form.selectedRace,
            onSelect: (race) {
              context.read<CharacterBloc>().add(
                    SelectRaceEvent(selectedRace: race),
                  );
            },
          ),
        CharacterCreationForm.abilitiesStep => AbilityScoresEditor(
            abilityScores: form.abilityScores,
            selectedRace: form.selectedRace,
            highlightedAbilities: form.selectedClass?.primaryAbilities ?? [],
            onChanged: (scores) {
              context.read<CharacterBloc>().add(
                    UpdateAbilityScoresEvent(abilityScores: scores),
                  );
            },
          ),
        CharacterCreationForm.backstoryStep => _BackstoryStep(form: form),
        _ => const SizedBox.shrink(),
      };
}

class _BackstoryStep extends StatefulWidget {
  const _BackstoryStep({required this.form});

  final CharacterCreationForm form;

  @override
  State<_BackstoryStep> createState() => _BackstoryStepState();
}

class _BackstoryStepState extends State<_BackstoryStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _backstoryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.form.name);
    _backstoryController = TextEditingController(text: widget.form.backstory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Резюме выбора
            _SelectionSummary(form: widget.form),
            const SizedBox(height: 20),

            // Имя персонажа
            _buildLabel(context, 'Имя персонажа *'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hintText: 'Введите имя...',
              onChanged: (value) {
                context.read<CharacterBloc>().add(
                      UpdateNameEvent(name: value),
                    );
              },
            ),
            const SizedBox(height: 24),

            // Предыстория
            _buildLabel(context, 'Предыстория (опционально)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _backstoryController,
              hintText: 'Расскажите историю персонажа...',
              maxLines: 5,
              maxLength: 2000,
              onChanged: (value) {
                context.read<CharacterBloc>().add(
                      UpdateBackstoryEvent(backstory: value),
                    );
              },
            ),
          ],
        ),
      );

  Widget _buildLabel(BuildContext context, String text) => Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: controller.text.isNotEmpty
                ? const Color(0xFFD4AF37)
                : const Color(0xFF2A2A4E),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
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
          onChanged: onChanged,
        ),
      );
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.form});

  final CharacterCreationForm form;

  @override
  Widget build(BuildContext context) => Container(
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
                  'Ваш выбор',
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
                  child: _SummaryItem(
                    icon: form.selectedClass?.iconEmoji ?? '⚔️',
                    label: 'Класс',
                    value: form.selectedClass?.nameRu ?? '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryItem(
                    icon: form.selectedRace?.iconEmoji ?? '👤',
                    label: 'Раса',
                    value: form.selectedRace?.nameRu ?? '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A2A4E)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bar_chart,
                    color: Color(0xFFD4AF37),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Характеристики: ${form.abilityScoresWithRacialBonus.values.join(', ')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _NavigationButtons extends StatelessWidget {
  const _NavigationButtons({
    required this.form,
    required this.isSubmitting,
  });

  final CharacterCreationForm form;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A4E), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            if (!form.isFirstStep)
              Expanded(
                child: _NavigationButton(
                  label: 'Назад',
                  icon: Icons.arrow_back,
                  isOutlined: true,
                  onPressed: isSubmitting
                      ? null
                      : () {
                          context.read<CharacterBloc>().add(
                                const PreviousStepEvent(),
                              );
                        },
                ),
              ),
            if (!form.isFirstStep) const SizedBox(width: 12),
            Expanded(
              child: _NavigationButton(
                label: form.isLastStep ? 'Создать' : 'Далее',
                icon: form.isLastStep ? Icons.check : Icons.arrow_forward,
                isOutlined: false,
                isLoading: isSubmitting,
                isDisabled: !form.canProceed,
                onPressed: !isSubmitting
                    ? () {
                        if (form.isLastStep) {
                          if (!form.canProceed) {
                            _showValidationError(context, form);
                            return;
                          }
                          HapticFeedback.mediumImpact();
                          context.read<CharacterBloc>().add(
                                const SubmitCreationEvent(),
                              );
                        } else {
                          if (!form.canProceed) {
                            _showValidationError(context, form);
                            return;
                          }
                          HapticFeedback.selectionClick();
                          context.read<CharacterBloc>().add(
                                const NextStepEvent(),
                              );
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      );

  void _showValidationError(BuildContext context, CharacterCreationForm form) {
    var error = '';
    switch (form.currentStep) {
      case 0:
        error = 'Выберите класс персонажа';
      case 1:
        error = 'Выберите расу персонажа';
      case 2:
        error = 'Распределите характеристики (сумма 60-90)';
      case 3:
        error = 'Введите имя персонажа';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: const Color(0xFFE76F51),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.label,
    required this.icon,
    required this.isOutlined,
    this.isLoading = false,
    this.isDisabled = false,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isOutlined;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDisabled
                ? const Color(0xFF3A3A5E)
                : isOutlined
                    ? const Color(0xFFD4AF37).withOpacity(0.1)
                    : const Color(0xFFD4AF37).withOpacity(0.15),
            border: Border.all(
              color: isDisabled
                  ? const Color(0xFF3A3A5E)
                  : isOutlined
                      ? const Color(0xFFD4AF37).withOpacity(0.3)
                      : const Color(0xFFD4AF37).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 20,
                  color: isDisabled
                      ? const Color(0xFF5A5A7E)
                      : const Color(0xFFD4AF37),
                ),
              if (!isLoading) const SizedBox(width: 6),
              if (!isLoading)
                Text(
                  label,
                  style: TextStyle(
                    color: isDisabled
                        ? const Color(0xFF5A5A7E)
                        : const Color(0xFFD4AF37),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      );
}
