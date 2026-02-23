import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/scenario_bloc.dart';
import '../bloc/scenario_event.dart';
import '../bloc/scenario_state.dart';

class ScenarioBuilderPage extends StatefulWidget { // null for new scenario, set for refinement

  const ScenarioBuilderPage({
    super.key,
    this.scenarioId,
  });
  final String? scenarioId;

  @override
  State<ScenarioBuilderPage> createState() => _ScenarioBuilderPageState();
}

class _ScenarioBuilderPageState extends State<ScenarioBuilderPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isRefining = false;

  @override
  void initState() {
    super.initState();
    _isRefining = widget.scenarioId != null;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

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
      appBar: AppBar(
        title: Text(_isRefining ? 'Доработать сценарий' : 'Создать сценарий'),
      ),
      body: BlocConsumer<ScenarioBloc, ScenarioState>(
        listener: (context, state) {
          state.maybeWhen(
            scenarioDetail: (scenario) {
              // Navigate to scenario preview on successful creation
              context.go('/scenarios/${scenario.id}');
            },
            error: (message) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.red,
                ),
              );
            },
            orElse: () {},
          );
        },
        builder: (context, state) {
          final isGenerating = state is ScenarioGenerating;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isRefining) ...[
                    const Text(
                      'Опишите свой сценарий',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Используйте естественный язык. AI создаст полноценный D&D сценарий с актами, персонажами и локациями.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    const Text(
                      'Доработка сценария',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Опишите, что вы хотите изменить или добавить в сценарий.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 12,
                    maxLength: _isRefining ? 1000 : 2000,
                    enabled: !isGenerating,
                    decoration: InputDecoration(
                      hintText: _isRefining
                          ? 'Например: Добавь больше драматических моментов в первый акт'
                          : 'Например: Средневековая фэнтези история о группе героев, которые должны остановить восстание нежити в королевстве...',
                      border: const OutlineInputBorder(),
                      filled: true,
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
                  const SizedBox(height: 24),
                  if (isGenerating) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            '🎲 AI создаёт ваш сценарий...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Это может занять до минуты',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isRefining ? 'Доработать' : 'Создать сценарий',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!_isRefining)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    color: Colors.amber,),
                                SizedBox(width: 8),
                                Text(
                                  'Советы',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text('• Укажите сеттинг (фэнтези, хоррор, научная фантастика)'),
                            Text('• Опишите основной конфликт или цель'),
                            Text('• Упомяните количество игроков'),
                            Text('• Задайте сложность (новички, опытные игроки)'),
                            Text('• Добавьте уникальные элементы или твисты'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
}
