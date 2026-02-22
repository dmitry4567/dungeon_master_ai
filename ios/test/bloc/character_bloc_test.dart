import 'package:ai_dungeon_master/features/character/bloc/character_bloc.dart';
import 'package:ai_dungeon_master/features/character/bloc/character_event.dart';
import 'package:ai_dungeon_master/features/character/bloc/character_state.dart';
import 'package:ai_dungeon_master/features/character/data/character_repository.dart';
import 'package:ai_dungeon_master/features/character/data/dnd_reference_data.dart';
import 'package:ai_dungeon_master/features/character/models/ability_scores.dart';
import 'package:ai_dungeon_master/features/character/models/character.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCharacterRepository extends Mock implements CharacterRepository {}

class FakeCreateCharacterRequest extends Fake
    implements CreateCharacterRequest {}

void main() {
  late MockCharacterRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeCreateCharacterRequest());
  });

  setUp(() {
    mockRepository = MockCharacterRepository();
  });

  group('CharacterBloc', () {
    final testCharacter = Character(
      id: '1',
      name: 'Test Hero',
      characterClass: 'fighter',
      race: 'human',
      level: 1,
      abilityScores: const AbilityScores(
        strength: 16,
        dexterity: 14,
        constitution: 14,
        intelligence: 10,
        wisdom: 10,
        charisma: 8,
      ),
      createdAt: DateTime(2024, 1, 1),
    );

    group('LoadCharacters', () {
      blocTest<CharacterBloc, CharacterState>(
        'emits [loading, loaded] when loading characters succeeds',
        build: () {
          when(() => mockRepository.getCharacters(forceRefresh: false))
              .thenAnswer((_) async => [testCharacter]);
          return CharacterBloc(mockRepository);
        },
        act: (bloc) => bloc.add(const CharacterEvent.loadCharacters()),
        expect: () => [
          const CharacterState.loading(),
          CharacterState.loaded(characters: [testCharacter]),
        ],
      );

      blocTest<CharacterBloc, CharacterState>(
        'emits [loading, error] when loading characters fails',
        build: () {
          when(() => mockRepository.getCharacters(forceRefresh: false))
              .thenThrow(Exception('Network error'));
          return CharacterBloc(mockRepository);
        },
        act: (bloc) => bloc.add(const CharacterEvent.loadCharacters()),
        expect: () => [
          const CharacterState.loading(),
          isA<CharacterError>(),
        ],
      );
    });

    group('StartCreation', () {
      blocTest<CharacterBloc, CharacterState>(
        'emits [creating] with empty form when starting creation',
        build: () => CharacterBloc(mockRepository),
        act: (bloc) => bloc.add(const CharacterEvent.startCreation()),
        expect: () => [
          const CharacterState.creating(form: CharacterCreationForm()),
        ],
      );
    });

    group('SelectClass', () {
      blocTest<CharacterBloc, CharacterState>(
        'updates form with selected class',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(form: CharacterCreationForm()),
        act: (bloc) => bloc.add(
          CharacterEvent.selectClass(
            selectedClass: DndReferenceData.classes.first,
          ),
        ),
        expect: () => [
          CharacterState.creating(
            form: CharacterCreationForm(
              selectedClass: DndReferenceData.classes.first,
            ),
          ),
        ],
      );
    });

    group('SelectRace', () {
      blocTest<CharacterBloc, CharacterState>(
        'updates form with selected race',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(form: CharacterCreationForm()),
        act: (bloc) => bloc.add(
          CharacterEvent.selectRace(
            selectedRace: DndReferenceData.races.first,
          ),
        ),
        expect: () => [
          CharacterState.creating(
            form: CharacterCreationForm(
              selectedRace: DndReferenceData.races.first,
            ),
          ),
        ],
      );
    });

    group('UpdateAbilityScores', () {
      blocTest<CharacterBloc, CharacterState>(
        'updates form with new ability scores',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(form: CharacterCreationForm()),
        act: (bloc) => bloc.add(
          const CharacterEvent.updateAbilityScores(
            abilityScores: AbilityScores(strength: 18),
          ),
        ),
        expect: () => [
          const CharacterState.creating(
            form: CharacterCreationForm(
              abilityScores: AbilityScores(strength: 18),
            ),
          ),
        ],
      );
    });

    group('UpdateName', () {
      blocTest<CharacterBloc, CharacterState>(
        'updates form with name',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(form: CharacterCreationForm()),
        act: (bloc) => bloc.add(
          const CharacterEvent.updateName(name: 'Hero Name'),
        ),
        expect: () => [
          const CharacterState.creating(
            form: CharacterCreationForm(name: 'Hero Name'),
          ),
        ],
      );
    });

    group('NextStep', () {
      blocTest<CharacterBloc, CharacterState>(
        'increments step when can proceed',
        build: () => CharacterBloc(mockRepository),
        seed: () => CharacterState.creating(
          form: CharacterCreationForm(
            selectedClass: DndReferenceData.classes.first,
          ),
        ),
        act: (bloc) => bloc.add(const CharacterEvent.nextStep()),
        expect: () => [
          CharacterState.creating(
            form: CharacterCreationForm(
              currentStep: 1,
              selectedClass: DndReferenceData.classes.first,
            ),
          ),
        ],
      );

      blocTest<CharacterBloc, CharacterState>(
        'does not increment step when cannot proceed',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(
          form: CharacterCreationForm(), // No class selected
        ),
        act: (bloc) => bloc.add(const CharacterEvent.nextStep()),
        expect: () => [], // No state change
      );
    });

    group('PreviousStep', () {
      blocTest<CharacterBloc, CharacterState>(
        'decrements step when not on first step',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(
          form: CharacterCreationForm(currentStep: 2),
        ),
        act: (bloc) => bloc.add(const CharacterEvent.previousStep()),
        expect: () => [
          const CharacterState.creating(
            form: CharacterCreationForm(currentStep: 1),
          ),
        ],
      );

      blocTest<CharacterBloc, CharacterState>(
        'does not decrement step when on first step',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(
          form: CharacterCreationForm(currentStep: 0),
        ),
        act: (bloc) => bloc.add(const CharacterEvent.previousStep()),
        expect: () => [], // No state change
      );
    });

    group('SubmitCreation', () {
      blocTest<CharacterBloc, CharacterState>(
        'emits [submitting, created] when creation succeeds',
        build: () {
          when(() => mockRepository.validateCharacter(any())).thenReturn([]);
          when(() => mockRepository.createCharacter(any()))
              .thenAnswer((_) async => testCharacter);
          return CharacterBloc(mockRepository);
        },
        seed: () => CharacterState.creating(
          form: CharacterCreationForm(
            selectedClass: DndReferenceData.classes.first,
            selectedRace: DndReferenceData.races.first,
            name: 'Test Hero',
            abilityScores: const AbilityScores(
              strength: 15,
              dexterity: 14,
              constitution: 13,
              intelligence: 12,
              wisdom: 10,
              charisma: 8,
            ),
          ),
        ),
        act: (bloc) => bloc.add(const CharacterEvent.submitCreation()),
        expect: () => [
          isA<CharacterSubmitting>(),
          CharacterState.created(character: testCharacter),
        ],
      );

      blocTest<CharacterBloc, CharacterState>(
        'emits [creating] with errors when form is incomplete',
        build: () => CharacterBloc(mockRepository),
        seed: () => const CharacterState.creating(
          form: CharacterCreationForm(), // Empty form
        ),
        act: (bloc) => bloc.add(const CharacterEvent.submitCreation()),
        expect: () => [
          isA<CharacterCreating>().having(
            (s) => s.form.validationErrors,
            'validationErrors',
            isNotEmpty,
          ),
        ],
      );
    });

    group('DeleteCharacter', () {
      blocTest<CharacterBloc, CharacterState>(
        'emits [loading, deleted] when deletion succeeds',
        build: () {
          when(() => mockRepository.deleteCharacter('1'))
              .thenAnswer((_) async {});
          return CharacterBloc(mockRepository);
        },
        act: (bloc) => bloc.add(const CharacterEvent.deleteCharacter(id: '1')),
        expect: () => [
          const CharacterState.loading(),
          const CharacterState.deleted(characterId: '1'),
        ],
      );
    });
  });

  group('CharacterCreationForm', () {
    test('canProceed returns true when class is selected on step 0', () {
      final form = CharacterCreationForm(
        currentStep: 0,
        selectedClass: DndReferenceData.classes.first,
      );

      expect(form.canProceed, isTrue);
    });

    test('canProceed returns false when no class selected on step 0', () {
      const form = CharacterCreationForm(currentStep: 0);

      expect(form.canProceed, isFalse);
    });

    test('canProceed returns true when race is selected on step 1', () {
      final form = CharacterCreationForm(
        currentStep: 1,
        selectedRace: DndReferenceData.races.first,
      );

      expect(form.canProceed, isTrue);
    });

    test('canProceed returns true when ability scores are valid on step 2', () {
      const form = CharacterCreationForm(
        currentStep: 2,
        abilityScores: AbilityScores(
          strength: 15,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 10,
          charisma: 8,
        ),
      );

      expect(form.canProceed, isTrue);
    });

    test('canProceed returns true when name is provided on step 3', () {
      const form = CharacterCreationForm(
        currentStep: 3,
        name: 'Hero',
      );

      expect(form.canProceed, isTrue);
    });

    test('progress returns correct value', () {
      expect(const CharacterCreationForm(currentStep: 0).progress, equals(0.25));
      expect(const CharacterCreationForm(currentStep: 1).progress, equals(0.5));
      expect(const CharacterCreationForm(currentStep: 2).progress, equals(0.75));
      expect(const CharacterCreationForm(currentStep: 3).progress, equals(1.0));
    });

    test('abilityScoresWithRacialBonus applies bonuses correctly', () {
      final form = CharacterCreationForm(
        selectedRace: DndReferenceData.races.firstWhere((r) => r.id == 'dwarf'),
        abilityScores: const AbilityScores(constitution: 14),
      );

      final withBonus = form.abilityScoresWithRacialBonus;
      expect(withBonus.constitution, equals(16)); // 14 + 2 racial bonus
    });
  });
}
