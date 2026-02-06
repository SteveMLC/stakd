import 'package:flutter_test/flutter_test.dart';
import 'package:stakd/models/layer_model.dart';
import 'package:stakd/models/stack_model.dart';
import 'package:stakd/services/level_generator.dart';

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
  });
}
