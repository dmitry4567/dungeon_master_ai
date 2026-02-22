import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../bloc/character_bloc.dart';
import '../bloc/character_event.dart';
import '../bloc/character_state.dart';
import '../models/character.dart';
import 'widgets/character_card.dart';

/// Страница списка персонажей
class CharacterListPage extends StatelessWidget {
  const CharacterListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Персонажи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CharacterBloc>().add(
                    const CharacterEvent.loadCharacters(forceRefresh: true),
                  );
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: BlocConsumer<CharacterBloc, CharacterState>(
        listener: (context, state) {
          if (state is CharacterDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Персонаж удалён'),
                backgroundColor: AppColors.success,
              ),
            );
            // Перезагрузить список
            context.read<CharacterBloc>().add(
                  const CharacterEvent.loadCharacters(),
                );
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
          return switch (state) {
            CharacterLoading() => const _LoadingView(),
            CharacterLoaded(:final characters) => characters.isEmpty
                ? const _EmptyView()
                : _CharacterListView(characters: characters),
            CharacterError(:final message) => ErrorView(
                message: message,
                onRetry: () {
                  context.read<CharacterBloc>().add(
                        const CharacterEvent.loadCharacters(),
                      );
                },
              ),
            _ => const _LoadingView(),
          };
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push(Routes.characterCreate);
          // Если персонаж был создан, обновить список
          if (result == true && context.mounted) {
            context.read<CharacterBloc>().add(
                  const CharacterEvent.loadCharacters(forceRefresh: true),
                );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Создать'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LoadingSkeleton(
          height: 120,
          borderRadius: 12,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(48),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 48,
                color: AppColors.outline,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'У вас нет персонажей',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте своего первого персонажа,\nчтобы начать приключение',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterListView extends StatelessWidget {
  const _CharacterListView({required this.characters});

  final List<Character> characters;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<CharacterBloc>().add(
              const CharacterEvent.loadCharacters(forceRefresh: true),
            );
        // Wait for state change
        await context.read<CharacterBloc>().stream.firstWhere(
              (state) => state is CharacterLoaded || state is CharacterError,
            );
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: characters.length,
        itemBuilder: (context, index) {
          final character = characters[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CharacterCard(
              character: character,
              onTap: () {
                context.push(Routes.characterDetailPath(character.id));
              },
              onLongPress: () {
                _showCharacterOptions(context, character);
              },
            ),
          );
        },
      ),
    );
  }

  void _showCharacterOptions(BuildContext context, Character character) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility, color: AppColors.onSurface),
                title: const Text('Просмотреть'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(Routes.characterDetailPath(character.id));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text(
                  'Удалить',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, character);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Character character) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить персонажа?'),
        content: Text(
          'Персонаж "${character.name}" будет удалён безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CharacterBloc>().add(
                    CharacterEvent.deleteCharacter(id: character.id),
                  );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
