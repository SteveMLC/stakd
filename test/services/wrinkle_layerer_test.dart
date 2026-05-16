import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_sort/models/layer_model.dart';
import 'package:warehouse_sort/models/stack_model.dart';
import 'package:warehouse_sort/services/wrinkle_layerer.dart';

/// Tests for the post-seed wrinkle layerer. Validates that wrinkles
/// only spawn when their token is in the list, and that mutual-
/// exclusion rules (fragile/priority/time-bomb on same top layer)
/// hold under repeated random seeds.
void main() {
  group('WrinkleLayerer.applyToBay', () {
    test('no wrinkles list → bay unchanged', () {
      final bay = _mixed();
      final out = WrinkleLayerer.applyToBay(bay, const <String>[],
          rng: Random(1));
      expect(out.layers.length, bay.layers.length);
      for (var i = 0; i < bay.layers.length; i++) {
        expect(out.layers[i].colorIndex, bay.layers[i].colorIndex);
        expect(out.layers[i].isFrozen, isFalse);
        expect(out.layers[i].isLocked, isFalse);
        expect(out.layers[i].isFragile, isFalse);
        expect(out.layers[i].isPriority, isFalse);
        expect(out.layers[i].isTimeBomb, isFalse);
      }
    });

    test('empty bay → empty bay (no errors)', () {
      final bay = GameStack(layers: const <Layer>[], maxDepth: 4);
      final out = WrinkleLayerer.applyToBay(bay, const ['frozen'],
          rng: Random(1));
      expect(out.layers, isEmpty);
    });

    test('layer count is conserved', () {
      final bay = _mixed();
      for (var seed = 1; seed <= 50; seed++) {
        final out = WrinkleLayerer.applyToBay(
          bay,
          const ['frozen', 'locked', 'fragile', 'priority', 'time-bomb', 'double-color'],
          rng: Random(seed),
        );
        expect(out.layers.length, bay.layers.length,
            reason: 'seed $seed lost or gained a layer');
      }
    });

    test('frozen wrinkle only spawns when in list', () {
      // 100 seeds with frozen NOT in list — never spawns.
      for (var seed = 1; seed <= 100; seed++) {
        final out = WrinkleLayerer.applyToBay(
          _mixed(),
          const ['locked'],
          rng: Random(seed),
        );
        expect(out.layers.any((l) => l.isFrozen), isFalse,
            reason: 'seed $seed spawned frozen without it being in the list');
      }
      // 100 seeds with frozen in list — at least one should spawn.
      var anyFrozenAcrossSeeds = false;
      for (var seed = 1; seed <= 100; seed++) {
        final out = WrinkleLayerer.applyToBay(
          _mixed(),
          const ['frozen'],
          rng: Random(seed),
        );
        if (out.layers.any((l) => l.isFrozen)) {
          anyFrozenAcrossSeeds = true;
          break;
        }
      }
      expect(anyFrozenAcrossSeeds, isTrue,
          reason: 'frozen wrinkle in list should produce at least one '
              'frozen spawn across 100 seeds');
    });

    test('fragile/priority/time-bomb are mutually exclusive in a bay', () {
      // Across many seeds, a bay should never have more than ONE of
      // these three wrinkles (the first-matching branch wins).
      for (var seed = 1; seed <= 200; seed++) {
        final out = WrinkleLayerer.applyToBay(
          _mixed(),
          const ['fragile', 'priority', 'time-bomb'],
          rng: Random(seed),
        );
        final fragileCount =
            out.layers.where((l) => l.isFragile).length;
        final priorityCount =
            out.layers.where((l) => l.isPriority).length;
        final timeBombCount =
            out.layers.where((l) => l.isTimeBomb).length;
        final urgentTotal = fragileCount + priorityCount + timeBombCount;
        expect(urgentTotal, lessThanOrEqualTo(1),
            reason: 'seed $seed: bay has $urgentTotal urgent wrinkles '
                '(fragile=$fragileCount, priority=$priorityCount, '
                'timeBomb=$timeBombCount) — should be ≤ 1');
      }
    });

    test('max 1 of each wrinkle type per bay (no over-spawn)', () {
      for (var seed = 1; seed <= 200; seed++) {
        final out = WrinkleLayerer.applyToBay(
          _mixed(),
          const ['frozen', 'locked', 'fragile', 'priority', 'time-bomb', 'double-color'],
          rng: Random(seed),
        );
        expect(out.layers.where((l) => l.isFrozen).length,
            lessThanOrEqualTo(1));
        expect(out.layers.where((l) => l.isLocked).length,
            lessThanOrEqualTo(1));
        expect(out.layers.where((l) => l.isFragile).length,
            lessThanOrEqualTo(1));
        expect(out.layers.where((l) => l.isPriority).length,
            lessThanOrEqualTo(1));
        expect(out.layers.where((l) => l.isTimeBomb).length,
            lessThanOrEqualTo(1));
      }
    });

    test('determinism: same seed → same wrinkle layout', () {
      final a = WrinkleLayerer.applyToBay(
        _mixed(),
        const ['frozen', 'locked', 'fragile', 'priority'],
        rng: Random(42),
      );
      final b = WrinkleLayerer.applyToBay(
        _mixed(),
        const ['frozen', 'locked', 'fragile', 'priority'],
        rng: Random(42),
      );
      for (var i = 0; i < a.layers.length; i++) {
        expect(a.layers[i].isFrozen, b.layers[i].isFrozen);
        expect(a.layers[i].isLocked, b.layers[i].isLocked);
        expect(a.layers[i].isFragile, b.layers[i].isFragile);
        expect(a.layers[i].isPriority, b.layers[i].isPriority);
        expect(a.layers[i].isTimeBomb, b.layers[i].isTimeBomb);
        expect(a.layers[i].colorIndex, b.layers[i].colorIndex);
      }
    });
  });

  group('WrinkleLayerer.applyToBays', () {
    test('applies to every bay in the list', () {
      final bays = [_mixed(), _mixed(colorOffset: 1), _mixed(colorOffset: 2)];
      final out = WrinkleLayerer.applyToBays(
        bays,
        const ['frozen'],
        rng: Random(1),
      );
      expect(out.length, bays.length);
      for (final b in out) {
        // Layer count conserved
        expect(b.layers.length, 4);
      }
    });
  });
}

/// 4-layer mixed-color bay test fixture.
GameStack _mixed({int colorOffset = 0}) => GameStack(
      layers: [
        Layer(colorIndex: 0 + colorOffset),
        Layer(colorIndex: 1 + colorOffset),
        Layer(colorIndex: 0 + colorOffset),
        Layer(colorIndex: 1 + colorOffset),
      ],
      maxDepth: 4,
    );
