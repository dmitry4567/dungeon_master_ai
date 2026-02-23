import 'package:ai_dungeon_master/features/character/models/ability_scores.dart';
import 'package:ai_dungeon_master/features/character/models/character.dart';
import 'package:ai_dungeon_master/features/character/ui/widgets/character_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testCharacter = Character(
    id: '1',
    name: 'Test Hero',
    characterClass: 'fighter',
    race: 'human',
    level: 5,
    abilityScores: const AbilityScores(
      strength: 16,
      dexterity: 14,
      constitution: 14,
      charisma: 8,
    ),
    backstory: 'A brave warrior',
    createdAt: DateTime(2024),
  );

  Widget buildTestWidget({
    required Character character,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: CharacterCard(
          character: character,
          onTap: onTap ?? () {},
          onLongPress: onLongPress,
        ),
      ),
    );

  group('CharacterCard', () {
    testWidgets('displays character name', (tester) async {
      await tester.pumpWidget(buildTestWidget(character: testCharacter));

      expect(find.text('Test Hero'), findsOneWidget);
    });

    testWidgets('displays race and class in Russian', (tester) async {
      await tester.pumpWidget(buildTestWidget(character: testCharacter));

      expect(find.text('Человек Воин'), findsOneWidget);
    });

    testWidgets('displays character level', (tester) async {
      await tester.pumpWidget(buildTestWidget(character: testCharacter));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('displays ability score values', (tester) async {
      await tester.pumpWidget(buildTestWidget(character: testCharacter));

      expect(find.text('СИЛ 16'), findsOneWidget);
      expect(find.text('ЛОВ 14'), findsOneWidget);
      expect(find.text('ТЕЛ 14'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestWidget(
        character: testCharacter,
        onTap: () => tapped = true,
      ),);

      await tester.tap(find.byType(CharacterCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('calls onLongPress when long pressed', (tester) async {
      var longPressed = false;
      await tester.pumpWidget(buildTestWidget(
        character: testCharacter,
        onLongPress: () => longPressed = true,
      ),);

      await tester.longPress(find.byType(CharacterCard));
      await tester.pump();

      expect(longPressed, isTrue);
    });

    testWidgets('has correct semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget(character: testCharacter));

      final semantics = tester.getSemantics(find.byType(CharacterCard));
      expect(semantics.label, contains('Test Hero'));
    });

    testWidgets('displays class emoji icon', (tester) async {
      await tester.pumpWidget(buildTestWidget(character: testCharacter));

      // Fighter class has sword emoji
      expect(find.text('⚔️'), findsOneWidget);
    });

    testWidgets('handles unknown class gracefully', (tester) async {
      final unknownClassCharacter = Character(
        id: '2',
        name: 'Unknown',
        characterClass: 'unknown_class',
        race: 'unknown_race',
        abilityScores: const AbilityScores(),
        createdAt: DateTime(2024),
      );

      await tester.pumpWidget(buildTestWidget(character: unknownClassCharacter));

      // Should display raw class/race names
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('unknown_race unknown_class'), findsOneWidget);
    });

    testWidgets('truncates long names with ellipsis', (tester) async {
      final longNameCharacter = Character(
        id: '3',
        name: 'A Very Long Character Name That Should Be Truncated',
        characterClass: 'fighter',
        race: 'human',
        abilityScores: const AbilityScores(),
        createdAt: DateTime(2024),
      );

      await tester.pumpWidget(buildTestWidget(character: longNameCharacter));

      final nameText = tester.widget<Text>(find.text(longNameCharacter.name));
      expect(nameText.overflow, equals(TextOverflow.ellipsis));
    });
  });
}
