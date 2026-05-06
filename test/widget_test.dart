import 'package:flutter_test/flutter_test.dart';
import 'package:stakd/models/game_state.dart';
import 'package:stakd/models/layer_model.dart';
import 'package:stakd/models/stack_model.dart';

/// Smoke tests for core gameplay logic.
///
/// We avoid pumping `StakdApp` directly because it depends on platform
/// channels (SharedPreferences, AdMob, IAP, etc.) that aren't available
/// in a unit-test environment. App-level integration tests should run
/// via `flutter test integration_test/` against a device or emulator.
void main() {
  group('GameState', () {
    test('initGame sets up a level with the given stacks', () {
      final state = GameState();
      final stacks = [
        GameStack(layers: [Layer(colorIndex: 0), Layer(colorIndex: 1)], maxDepth: 2),
        GameStack(layers: [Layer(colorIndex: 1), Layer(colorIndex: 0)], maxDepth: 2),
        GameStack(layers: [], maxDepth: 2),
      ];

      state.initGame(stacks, 1, par: 4);

      expect(state.stacks.length, 3);
      expect(state.currentLevel, 1);
      expect(state.par, 4);
      expect(state.moveCount, 0);
      expect(state.isComplete, isFalse);
      expect(state.canUndo, isFalse);
    });

    test('selecting an empty stack does nothing', () {
      final state = GameState();
      state.initGame([
        GameStack(layers: [Layer(colorIndex: 0)], maxDepth: 2),
        GameStack(layers: [], maxDepth: 2),
      ], 1);

      state.onStackTap(1);
      expect(state.selectedStackIndex, -1);
    });

    test('tap-tap moves a layer between stacks', () {
      final state = GameState();
      state.initGame([
        GameStack(layers: [Layer(colorIndex: 0)], maxDepth: 2),
        GameStack(layers: [], maxDepth: 2),
      ], 1);

      state.onStackTap(0);
      expect(state.selectedStackIndex, 0);

      state.onStackTap(1);
      // Move animation begins; the source stack is emptied immediately.
      expect(state.stacks[0].layers, isEmpty);
      expect(state.animatingLayer, isNotNull);
      expect(state.animatingLayer!.fromStackIndex, 0);
      expect(state.animatingLayer!.toStackIndex, 1);
    });

    test('tapping the same stack twice deselects', () {
      final state = GameState();
      state.initGame([
        GameStack(layers: [Layer(colorIndex: 0)], maxDepth: 2),
        GameStack(layers: [], maxDepth: 2),
      ], 1);

      state.onStackTap(0);
      state.onStackTap(0);
      expect(state.selectedStackIndex, -1);
    });

    test('a sorted-color level has only complete or empty stacks', () {
      final state = GameState();
      state.initGame([
        GameStack(layers: [Layer(colorIndex: 0), Layer(colorIndex: 0)], maxDepth: 2),
        GameStack(layers: [Layer(colorIndex: 1), Layer(colorIndex: 1)], maxDepth: 2),
        GameStack(layers: [], maxDepth: 2),
      ], 1);

      expect(
        state.stacks.where((s) => s.isEmpty || s.isComplete).length,
        state.stacks.length,
      );
    });
  });
}
