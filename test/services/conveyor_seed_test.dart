import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_sort/services/conveyor_seed.dart';

/// Tests for the reverse-construction seed generator.
///
/// The most important assertion in this file is **inviolable #1** from the
/// conveyor-mechanic spec: the generator must NEVER produce a state with a
/// pre-solved bay (single-color, full-depth). We test that across 100
/// reproducible seeds at every difficulty band, so any future regression
/// to seed parameters or algorithm tuning trips immediately.
void main() {
  group('ConveyorSeed reverse-construction generator', () {
    test('produces correct bay count (numColors + numEmptyBays)', () {
      for (final cfg in _difficultyBands) {
        final bays = ConveyorSeed.generateBays(
          numColors: cfg.numColors,
          bayDepth: cfg.bayDepth,
          numEmptyBays: cfg.numEmptyBays,
          scrambleMoves: cfg.scrambleMoves,
          rng: Random(42),
        );
        expect(
          bays.length,
          cfg.numColors + cfg.numEmptyBays,
          reason: 'band ${cfg.label}: expected ${cfg.numColors + cfg.numEmptyBays} bays',
        );
      }
    });

    test('no bay exceeds bayDepth', () {
      for (final cfg in _difficultyBands) {
        final bays = ConveyorSeed.generateBays(
          numColors: cfg.numColors,
          bayDepth: cfg.bayDepth,
          numEmptyBays: cfg.numEmptyBays,
          scrambleMoves: cfg.scrambleMoves,
          rng: Random(42),
        );
        for (var i = 0; i < bays.length; i++) {
          expect(
            bays[i].layers.length,
            lessThanOrEqualTo(cfg.bayDepth),
            reason: 'band ${cfg.label} bay $i exceeded depth',
          );
        }
      }
    });

    test('total layer count equals numColors * bayDepth', () {
      // Reverse-construction conserves total layer count — it only moves
      // layers between bays, never adds or removes them.
      for (final cfg in _difficultyBands) {
        final bays = ConveyorSeed.generateBays(
          numColors: cfg.numColors,
          bayDepth: cfg.bayDepth,
          numEmptyBays: cfg.numEmptyBays,
          scrambleMoves: cfg.scrambleMoves,
          rng: Random(42),
        );
        final totalLayers =
            bays.fold<int>(0, (sum, b) => sum + b.layers.length);
        expect(
          totalLayers,
          cfg.numColors * cfg.bayDepth,
          reason: 'band ${cfg.label}: layer count must be conserved',
        );
      }
    });

    test('each color appears exactly bayDepth times total', () {
      for (final cfg in _difficultyBands) {
        final bays = ConveyorSeed.generateBays(
          numColors: cfg.numColors,
          bayDepth: cfg.bayDepth,
          numEmptyBays: cfg.numEmptyBays,
          scrambleMoves: cfg.scrambleMoves,
          rng: Random(42),
        );
        final counts = <int, int>{};
        for (final b in bays) {
          for (final l in b.layers) {
            counts[l.colorIndex] = (counts[l.colorIndex] ?? 0) + 1;
          }
        }
        for (var c = 0; c < cfg.numColors; c++) {
          expect(
            counts[c],
            cfg.bayDepth,
            reason: 'band ${cfg.label}: color $c appeared '
                '${counts[c]}× (expected ${cfg.bayDepth})',
          );
        }
      }
    });

    test('INVIOLABLE: no pre-solved bay at construction (100 seeds × every band)',
        () {
      for (final cfg in _difficultyBands) {
        for (var seed = 1; seed <= 100; seed++) {
          final bays = ConveyorSeed.generateBays(
            numColors: cfg.numColors,
            bayDepth: cfg.bayDepth,
            numEmptyBays: cfg.numEmptyBays,
            scrambleMoves: cfg.scrambleMoves,
            rng: Random(seed),
          );
          for (var bayIdx = 0; bayIdx < bays.length; bayIdx++) {
            final bay = bays[bayIdx];
            // Pre-solved = full depth + all same color.
            if (bay.layers.length != cfg.bayDepth) continue;
            final firstColor = bay.layers.first.colorIndex;
            final allSame =
                bay.layers.every((l) => l.colorIndex == firstColor);
            expect(
              allSame,
              isFalse,
              reason: 'band ${cfg.label} seed $seed bay $bayIdx '
                  'rendered pre-solved (color $firstColor × ${cfg.bayDepth}). '
                  'This violates spec inviolable #1.',
            );
          }
        }
      }
    });

    test('puzzle is non-trivial: at least one bay has >1 distinct color', () {
      // A 1-color bay is fine if it's just because that color clustered;
      // but if EVERY bay has only one distinct color (i.e. nothing mixed
      // happened), the scramble was too short. Catches degenerate
      // scrambleMoves values.
      for (final cfg in _difficultyBands) {
        final bays = ConveyorSeed.generateBays(
          numColors: cfg.numColors,
          bayDepth: cfg.bayDepth,
          numEmptyBays: cfg.numEmptyBays,
          scrambleMoves: cfg.scrambleMoves,
          rng: Random(42),
        );
        final anyMixed = bays.any((b) {
          if (b.layers.isEmpty) return false;
          final firstColor = b.layers.first.colorIndex;
          return b.layers.any((l) => l.colorIndex != firstColor);
        });
        expect(
          anyMixed,
          isTrue,
          reason: 'band ${cfg.label}: scramble too shallow, '
              'no bay has mixed colors',
        );
      }
    });

    test('determinism: same seed produces same output', () {
      const cfg = _DifficultyBand(
        label: 'determinism',
        numColors: 4,
        bayDepth: 4,
        numEmptyBays: 2,
        scrambleMoves: 50,
      );
      final a = ConveyorSeed.generateBays(
        numColors: cfg.numColors,
        bayDepth: cfg.bayDepth,
        numEmptyBays: cfg.numEmptyBays,
        scrambleMoves: cfg.scrambleMoves,
        rng: Random(777),
      );
      final b = ConveyorSeed.generateBays(
        numColors: cfg.numColors,
        bayDepth: cfg.bayDepth,
        numEmptyBays: cfg.numEmptyBays,
        scrambleMoves: cfg.scrambleMoves,
        rng: Random(777),
      );
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(
          a[i].layers.map((l) => l.colorIndex).toList(),
          b[i].layers.map((l) => l.colorIndex).toList(),
          reason: 'bay $i differs between runs with the same seed',
        );
      }
    });
  });
}

/// Mirrors the difficulty bands in `docs/conveyor-mechanic-spec.md`
/// section 4.3 — every band the level config will ever ask for.
const _difficultyBands = <_DifficultyBand>[
  _DifficultyBand(
    label: 'L1-5 intro',
    numColors: 3,
    bayDepth: 4,
    numEmptyBays: 2,
    scrambleMoves: 24,
  ),
  _DifficultyBand(
    label: 'L6-15',
    numColors: 4,
    bayDepth: 4,
    numEmptyBays: 2,
    scrambleMoves: 48,
  ),
  _DifficultyBand(
    label: 'L16-30',
    numColors: 5,
    bayDepth: 4,
    numEmptyBays: 2,
    scrambleMoves: 80,
  ),
  _DifficultyBand(
    label: 'L31-60',
    numColors: 6,
    bayDepth: 5,
    numEmptyBays: 2,
    scrambleMoves: 150,
  ),
  _DifficultyBand(
    label: 'L61-100',
    numColors: 7,
    bayDepth: 5,
    numEmptyBays: 2,
    scrambleMoves: 210,
  ),
  _DifficultyBand(
    label: 'L100+',
    numColors: 7,
    bayDepth: 5,
    numEmptyBays: 1,
    scrambleMoves: 280,
  ),
];

class _DifficultyBand {
  final String label;
  final int numColors;
  final int bayDepth;
  final int numEmptyBays;
  final int scrambleMoves;

  const _DifficultyBand({
    required this.label,
    required this.numColors,
    required this.bayDepth,
    required this.numEmptyBays,
    required this.scrambleMoves,
  });
}
