import 'package:flutter_test/flutter_test.dart';
import 'package:stakd/models/layer_model.dart';
import 'package:stakd/models/stack_model.dart';
import 'package:stakd/services/level_generator.dart';
import 'package:stakd/utils/constants.dart';

void main() {
  group('LevelGenerator', () {
    test('generated solvable levels are solvable', () {
      final generator = LevelGenerator(seed: 42);
      for (final level in [1, 2, 3]) {
        final stacks = generator.generateSolvableLevel(level);
        final solvable = generator.isSolvable(stacks, maxStates: 5000);
        expect(solvable, isTrue, reason: 'Level $level should be solvable');
      }
    });

    test('solved state is solvable', () {
      final stacks = [
        GameStack(
          layers: [Layer(colorIndex: 0), Layer(colorIndex: 0)],
          maxDepth: 2,
        ),
        GameStack(
          layers: [Layer(colorIndex: 1), Layer(colorIndex: 1)],
          maxDepth: 2,
        ),
        GameStack(layers: [], maxDepth: 2),
      ];
      final generator = LevelGenerator(seed: 7);
      expect(generator.isSolvable(stacks, maxStates: 1000), isTrue);
    });

    test('difficulty score increases with color mixing', () {
      final generator = LevelGenerator(seed: 1);

      // Sorted stacks (easy) - low score
      final easyStacks = [
        GameStack(
          layers: [Layer(colorIndex: 0), Layer(colorIndex: 0)],
          maxDepth: 3,
        ),
        GameStack(
          layers: [Layer(colorIndex: 1), Layer(colorIndex: 1)],
          maxDepth: 3,
        ),
        GameStack(layers: [], maxDepth: 3),
      ];

      // Mixed stacks (hard) - higher score
      final hardStacks = [
        GameStack(
          layers: [Layer(colorIndex: 0), Layer(colorIndex: 1), Layer(colorIndex: 0)],
          maxDepth: 3,
        ),
        GameStack(
          layers: [Layer(colorIndex: 1), Layer(colorIndex: 0), Layer(colorIndex: 1)],
          maxDepth: 3,
        ),
        GameStack(layers: [], maxDepth: 3),
      ];

      final easyScore = generator.difficultyScore(easyStacks);
      final hardScore = generator.difficultyScore(hardStacks);

      expect(hardScore, greaterThan(easyScore),
          reason: 'Mixed stacks should have higher difficulty score');
    });

    test('par calculation returns valid move count', () {
      final generator = LevelGenerator(seed: 1);

      // Simple puzzle that requires exactly 2 moves
      final stacks = [
        GameStack(
          layers: [Layer(colorIndex: 0), Layer(colorIndex: 1)],
          maxDepth: 2,
        ),
        GameStack(
          layers: [Layer(colorIndex: 1), Layer(colorIndex: 0)],
          maxDepth: 2,
        ),
        GameStack(layers: [], maxDepth: 2),
      ];

      final par = generator.calculatePar(stacks);
      expect(par, isNotNull, reason: 'Par should be calculable');
      expect(par, greaterThan(0), reason: 'Par should be positive');
    });

    test('generateLevelWithPar returns level and par', () {
      final generator = LevelGenerator(seed: 42);

      final (stacks, par) = generator.generateLevelWithPar(1);

      expect(stacks, isNotEmpty, reason: 'Should generate stacks');
      expect(par, isNotNull, reason: 'Should calculate par for simple levels');
      expect(par, greaterThan(0), reason: 'Par should be positive');
    });

    test('high levels have fewer empty slots', () {
      final level50Params = LevelParams.forLevel(50);
      final level60Params = LevelParams.forLevel(60);
      final level80Params = LevelParams.forLevel(80);

      expect(level50Params.emptySlots, equals(1),
          reason: 'Level 50 should have only 1 empty slot');
      expect(level60Params.emptySlots, equals(1),
          reason: 'Level 60 should have only 1 empty slot');
      expect(level80Params.emptySlots, equals(1),
          reason: 'Level 80 should have only 1 empty slot');
    });

    test('high level puzzles are still solvable', () {
      final generator = LevelGenerator(seed: 42);

      // Test levels in the new difficulty range
      for (final level in [51, 60, 75, 100]) {
        final stacks = generator.generateSolvableLevel(level);
        final solvable = generator.isSolvable(stacks, maxStates: 10000);
        expect(solvable, isTrue, reason: 'Level $level should be solvable');
      }
    });
  });
}
