import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/dnd_data.dart';

part 'character_event.freezed.dart';

/// События CharacterBloc
@freezed
sealed class CharacterEvent with _$CharacterEvent {
  /// Загрузить список персонажей
  const factory CharacterEvent.loadCharacters({
    @Default(false) bool forceRefresh,
  }) = LoadCharactersEvent;

  /// Загрузить конкретного персонажа
  const factory CharacterEvent.loadCharacter({
    required String id,
    @Default(false) bool forceRefresh,
  }) = LoadCharacterEvent;

  /// Начать создание персонажа (сброс формы)
  const factory CharacterEvent.startCreation() = StartCreationEvent;

  /// Выбрать класс
  const factory CharacterEvent.selectClass({
    required DndClass selectedClass,
  }) = SelectClassEvent;

  /// Выбрать расу
  const factory CharacterEvent.selectRace({
    required DndRace selectedRace,
  }) = SelectRaceEvent;

  /// Обновить характеристики
  const factory CharacterEvent.updateAbilityScores({
    required AbilityScores abilityScores,
  }) = UpdateAbilityScoresEvent;

  /// Обновить имя
  const factory CharacterEvent.updateName({
    required String name,
  }) = UpdateNameEvent;

  /// Обновить предысторию
  const factory CharacterEvent.updateBackstory({
    required String backstory,
  }) = UpdateBackstoryEvent;

  /// Отправить форму создания
  const factory CharacterEvent.submitCreation() = SubmitCreationEvent;

  /// Удалить персонажа
  const factory CharacterEvent.deleteCharacter({
    required String id,
  }) = DeleteCharacterEvent;

  /// Обновить персонажа
  const factory CharacterEvent.updateCharacter({
    required String id,
    required UpdateCharacterRequest request,
  }) = UpdateCharacterEvent;

  /// Перейти к следующему шагу мастера
  const factory CharacterEvent.nextStep() = NextStepEvent;

  /// Вернуться к предыдущему шагу
  const factory CharacterEvent.previousStep() = PreviousStepEvent;

  /// Очистить ошибку
  const factory CharacterEvent.clearError() = ClearErrorEvent;
}
