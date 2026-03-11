import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/dnd_data.dart';

/// События CharacterBloc
abstract class CharacterEvent {
  const CharacterEvent();
}

/// Загрузить список персонажей
class LoadCharactersEvent extends CharacterEvent {
  final bool forceRefresh;

  const LoadCharactersEvent({this.forceRefresh = false});
}

/// Загрузить конкретного персонажа
class LoadCharacterEvent extends CharacterEvent {
  final String id;
  final bool forceRefresh;

  const LoadCharacterEvent({
    required this.id,
    this.forceRefresh = false,
  });
}

/// Начать создание персонажа (сброс формы)
class StartCreationEvent extends CharacterEvent {
  const StartCreationEvent();
}

/// Выбрать класс
class SelectClassEvent extends CharacterEvent {
  final DndClass selectedClass;

  const SelectClassEvent({required this.selectedClass});
}

/// Выбрать расу
class SelectRaceEvent extends CharacterEvent {
  final DndRace selectedRace;

  const SelectRaceEvent({required this.selectedRace});
}

/// Обновить характеристики
class UpdateAbilityScoresEvent extends CharacterEvent {
  final AbilityScores abilityScores;

  const UpdateAbilityScoresEvent({required this.abilityScores});
}

/// Обновить имя
class UpdateNameEvent extends CharacterEvent {
  final String name;

  const UpdateNameEvent({required this.name});
}

/// Обновить предысторию
class UpdateBackstoryEvent extends CharacterEvent {
  final String backstory;

  const UpdateBackstoryEvent({required this.backstory});
}

/// Отправить форму создания
class SubmitCreationEvent extends CharacterEvent {
  const SubmitCreationEvent();
}

/// Удалить персонажа
class DeleteCharacterEvent extends CharacterEvent {
  final String id;

  const DeleteCharacterEvent({required this.id});
}

/// Обновить персонажа
class UpdateCharacterEvent extends CharacterEvent {
  final String id;
  final UpdateCharacterRequest request;

  const UpdateCharacterEvent({
    required this.id,
    required this.request,
  });
}

/// Перейти к следующему шагу мастера
class NextStepEvent extends CharacterEvent {
  const NextStepEvent();
}

/// Вернуться к предыдущему шагу
class PreviousStepEvent extends CharacterEvent {
  const PreviousStepEvent();
}

/// Очистить ошибку
class ClearErrorEvent extends CharacterEvent {
  const ClearErrorEvent();
}
