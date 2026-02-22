import 'package:ai_dungeon_master/features/character/models/ability_scores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AbilityScores', () {
    group('calculateModifier', () {
      test('returns -5 for score 1', () {
        expect(AbilityScores.calculateModifier(1), equals(-5));
      });

      test('returns -4 for score 2-3', () {
        expect(AbilityScores.calculateModifier(2), equals(-4));
        expect(AbilityScores.calculateModifier(3), equals(-4));
      });

      test('returns -1 for score 8-9', () {
        expect(AbilityScores.calculateModifier(8), equals(-1));
        expect(AbilityScores.calculateModifier(9), equals(-1));
      });

      test('returns 0 for score 10-11', () {
        expect(AbilityScores.calculateModifier(10), equals(0));
        expect(AbilityScores.calculateModifier(11), equals(0));
      });

      test('returns +1 for score 12-13', () {
        expect(AbilityScores.calculateModifier(12), equals(1));
        expect(AbilityScores.calculateModifier(13), equals(1));
      });

      test('returns +2 for score 14-15', () {
        expect(AbilityScores.calculateModifier(14), equals(2));
        expect(AbilityScores.calculateModifier(15), equals(2));
      });

      test('returns +5 for score 20', () {
        expect(AbilityScores.calculateModifier(20), equals(5));
      });
    });

    group('modifiers', () {
      test('calculates all modifiers correctly', () {
        const scores = AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 12,
          intelligence: 10,
          wisdom: 8,
          charisma: 6,
        );

        expect(scores.strengthModifier, equals(3));
        expect(scores.dexterityModifier, equals(2));
        expect(scores.constitutionModifier, equals(1));
        expect(scores.intelligenceModifier, equals(0));
        expect(scores.wisdomModifier, equals(-1));
        expect(scores.charismaModifier, equals(-2));
      });

      test('getModifier works with English names', () {
        const scores = AbilityScores(strength: 18);

        expect(scores.getModifier('strength'), equals(4));
        expect(scores.getModifier('str'), equals(4));
        expect(scores.getModifier('STRENGTH'), equals(4));
      });

      test('getModifier works with Russian names', () {
        const scores = AbilityScores(strength: 18);

        expect(scores.getModifier('сила'), equals(4));
      });

      test('getModifier returns 0 for unknown ability', () {
        const scores = AbilityScores();

        expect(scores.getModifier('unknown'), equals(0));
      });
    });

    group('total', () {
      test('calculates sum of all abilities', () {
        const scores = AbilityScores(
          strength: 15,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 10,
          charisma: 8,
        );

        expect(scores.total, equals(72));
      });

      test('default scores total 60', () {
        const scores = AbilityScores();
        expect(scores.total, equals(60));
      });
    });

    group('values', () {
      test('returns list of all values', () {
        const scores = AbilityScores(
          strength: 15,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 10,
          charisma: 8,
        );

        expect(scores.values, equals([15, 14, 13, 12, 10, 8]));
      });
    });

    group('getValue', () {
      test('returns correct value for each ability', () {
        const scores = AbilityScores(
          strength: 15,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 10,
          charisma: 8,
        );

        expect(scores.getValue('strength'), equals(15));
        expect(scores.getValue('dexterity'), equals(14));
        expect(scores.getValue('constitution'), equals(13));
        expect(scores.getValue('intelligence'), equals(12));
        expect(scores.getValue('wisdom'), equals(10));
        expect(scores.getValue('charisma'), equals(8));
      });
    });

    group('withAbility', () {
      test('creates copy with modified ability', () {
        const original = AbilityScores(strength: 10);
        final modified = original.withAbility('strength', 18);

        expect(original.strength, equals(10));
        expect(modified.strength, equals(18));
      });

      test('returns same object for unknown ability', () {
        const original = AbilityScores();
        final result = original.withAbility('unknown', 18);

        expect(result, equals(original));
      });
    });

    group('serialization', () {
      test('toJson creates valid map', () {
        const scores = AbilityScores(
          strength: 15,
          dexterity: 14,
          constitution: 13,
          intelligence: 12,
          wisdom: 10,
          charisma: 8,
        );

        final json = scores.toJson();

        expect(json['strength'], equals(15));
        expect(json['dexterity'], equals(14));
        expect(json['constitution'], equals(13));
        expect(json['intelligence'], equals(12));
        expect(json['wisdom'], equals(10));
        expect(json['charisma'], equals(8));
      });

      test('fromJson parses correctly', () {
        final json = {
          'strength': 15,
          'dexterity': 14,
          'constitution': 13,
          'intelligence': 12,
          'wisdom': 10,
          'charisma': 8,
        };

        final scores = AbilityScores.fromJson(json);

        expect(scores.strength, equals(15));
        expect(scores.dexterity, equals(14));
        expect(scores.constitution, equals(13));
        expect(scores.intelligence, equals(12));
        expect(scores.wisdom, equals(10));
        expect(scores.charisma, equals(8));
      });
    });
  });
}
