import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/fantasy_button.dart';
import '../bloc/character_bloc.dart';
import '../bloc/character_event.dart';
import '../bloc/character_state.dart';
import 'widgets/ability_scores_editor.dart';
import 'widgets/class_selector.dart';
import 'widgets/race_selector.dart';

/// Страница создания персонажа (мастер)
class CharacterCreatePage extends StatelessWidget {
  const CharacterCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CharacterBloc, CharacterState>(
      listener: (context, state) {
        if (state is CharacterCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Персонаж "${state.character.name}" создан!'),
              backgroundColor: AppColors.success,
            ),
          );
          // Вернуться к списку персонажей с результатом
          context.pop(true);
        } else if (state is CharacterError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is! CharacterCreating && state is! CharacterSubmitting) {
          // Если состояние не создания, начать создание
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<CharacterBloc>().add(
                  const CharacterEvent.startCreation(),
                );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
                    const CharacterEvent.previousStep(),
                  );
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Создание персонажа'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ),
            body: Column(
              children: [
                // Прогресс-индикатор
                _ProgressIndicator(
                  currentStep: form.currentStep,
                  totalSteps: CharacterCreationForm.totalSteps,
                ),

                // Заголовок шага
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${form.currentStep + 1}',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        form.currentStepTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.onSurface,
                            ),
                      ),
                    ],
                  ),
                ),

                // Ошибки валидации
                if (form.validationErrors.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            form.validationErrors.join('\n'),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.error,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
        );
      },
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (currentStep + 1) / totalSteps,
      backgroundColor: AppColors.surfaceVariant,
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      minHeight: 4,
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({required this.form});

  final CharacterCreationForm form;

  @override
  Widget build(BuildContext context) {
    return switch (form.currentStep) {
      CharacterCreationForm.classStep => ClassSelector(
          selectedClass: form.selectedClass,
          onSelect: (dndClass) {
            context.read<CharacterBloc>().add(
                  CharacterEvent.selectClass(selectedClass: dndClass),
                );
          },
        ),
      CharacterCreationForm.raceStep => RaceSelector(
          selectedRace: form.selectedRace,
          onSelect: (race) {
            context.read<CharacterBloc>().add(
                  CharacterEvent.selectRace(selectedRace: race),
                );
          },
        ),
      CharacterCreationForm.abilitiesStep => AbilityScoresEditor(
          abilityScores: form.abilityScores,
          selectedRace: form.selectedRace,
          highlightedAbilities: form.selectedClass?.primaryAbilities ?? [],
          onChanged: (scores) {
            context.read<CharacterBloc>().add(
                  CharacterEvent.updateAbilityScores(abilityScores: scores),
                );
          },
        ),
      CharacterCreationForm.backstoryStep => _BackstoryStep(form: form),
      _ => const SizedBox.shrink(),
    };
  }
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Резюме выбора
          _SelectionSummary(form: widget.form),
          const SizedBox(height: 24),

          // Имя персонажа
          Text(
            'Имя персонажа *',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Введите имя...',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.onSurface,
                ),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              context.read<CharacterBloc>().add(
                    CharacterEvent.updateName(name: value),
                  );
            },
          ),
          const SizedBox(height: 24),

          // Предыстория
          Text(
            'Предыстория (опционально)',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _backstoryController,
            decoration: InputDecoration(
              hintText: 'Расскажите историю персонажа...',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              alignLabelWithHint: true,
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.onSurface,
                ),
            maxLines: 5,
            maxLength: 2000,
            onChanged: (value) {
              context.read<CharacterBloc>().add(
                    CharacterEvent.updateBackstory(backstory: value),
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.form});

  final CharacterCreationForm form;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ваш выбор',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Класс
              Expanded(
                child: _SummaryItem(
                  icon: form.selectedClass?.iconEmoji ?? '⚔️',
                  label: 'Класс',
                  value: form.selectedClass?.nameRu ?? '-',
                ),
              ),
              const SizedBox(width: 12),
              // Раса
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
          // Характеристики
          Text(
            'Характеристики: ${form.abilityScoresWithRacialBonus.values.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavigationButtons extends StatelessWidget {
  const _NavigationButtons({
    required this.form,
    required this.isSubmitting,
  });

  final CharacterCreationForm form;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Кнопка "Назад"
            if (!form.isFirstStep)
              Expanded(
                child: FantasyButton(
                  label: 'Назад',
                  variant: FantasyButtonVariant.outline,
                  onPressed: isSubmitting
                      ? null
                      : () {
                          context.read<CharacterBloc>().add(
                                const CharacterEvent.previousStep(),
                              );
                        },
                ),
              ),
            if (!form.isFirstStep) const SizedBox(width: 12),

            // Кнопка "Далее" или "Создать"
            Expanded(
              child: FantasyButton(
                label: form.isLastStep ? 'Создать персонажа' : 'Далее',
                icon: form.isLastStep ? Icons.check : Icons.arrow_forward,
                isLoading: isSubmitting,
                isDisabled: !form.canProceed,
                onPressed: form.canProceed && !isSubmitting
                    ? () {
                        if (form.isLastStep) {
                          context.read<CharacterBloc>().add(
                                const CharacterEvent.submitCreation(),
                              );
                        } else {
                          context.read<CharacterBloc>().add(
                                const CharacterEvent.nextStep(),
                              );
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
