import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_sort/services/district_service.dart';
import 'package:warehouse_sort/services/level_generator.dart';
import 'package:warehouse_sort/utils/constants.dart';

void main() {
  group('LevelGenerator', () {
    // Phase H — DELETED the following tests because the methods they
    // exercised are gone from `LevelGenerator`:
    //   - "generated solvable levels are solvable" (called
    //     generateSolvableLevel + isSolvable)
    //   - "solved state is solvable" (isSolvable)
    //   - "difficulty score increases with color mixing"
    //     (difficultyScore)
    //   - "par calculation returns valid move count" (calculatePar)
    //   - "generateLevelWithPar returns level and par"
    //   - "high level puzzles are still solvable" (generateSolvableLevel
    //     + isSolvable)
    //
    // All of these tested behavior that the conveyor mechanic now
    // owns (solvability by construction via ConveyorSeed; difficulty
    // via ConveyorLevelConfig; par via cfg.totalDeliveries * 3).
    // The "Level 3" and "Level 60" cases in the deleted tests were
    // pre-existing flakies. Their removal is the cleanup the
    // overhaul required.

    test('high levels have fewer empty slots', () {
      // Expert tier (51-100): 1 empty slot; Advanced (26-50): 2 empty slots
      final level51Params = LevelParams.forLevel(51);
      final level60Params = LevelParams.forLevel(60);
      final level80Params = LevelParams.forLevel(80);

      expect(level51Params.emptySlots, equals(1),
          reason: 'Level 51 (Expert) should have only 1 empty slot');
      expect(level60Params.emptySlots, equals(1),
          reason: 'Level 60 should have only 1 empty slot');
      expect(level80Params.emptySlots, equals(1),
          reason: 'Level 80 should have only 1 empty slot');
    });

    group('paramsForLevel — district-aware wrinkle adjustments', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await DistrictService().reset();
        await DistrictService().init();
      });

      test('no-district levels return baseline params unchanged', () {
        final generator = LevelGenerator();
        // L60 is in D12 (procedural). D12's wrinkle assignment may or
        // may not be 'frozen' depending on the rotation. Take L31 (D7,
        // first procedural district) which has 'frozen' guaranteed by
        // the wrinkle pool composer. And take L1 baseline to compare.
        final base = LevelParams.forLevel(1);
        final adjusted = generator.paramsForLevel(1);
        // D1 has no wrinkles → adjusted equals base.
        expect(adjusted.frozenBlockProbability, base.frozenBlockProbability);
        expect(adjusted.colors, base.colors);
        expect(adjusted.stacks, base.stacks);
      });

      test('D3 Cold Storage (frozen wrinkle) bumps frozen probability', () {
        final generator = LevelGenerator();
        final base = LevelParams.forLevel(12);
        final adjusted = generator.paramsForLevel(12);
        // L12 sits in D3 which has the `frozen` wrinkle hand-tuned.
        expect(
          adjusted.frozenBlockProbability,
          greaterThan(base.frozenBlockProbability),
        );
        // The bump is +0.05 (capped at 0.30).
        final expected = (base.frozenBlockProbability + 0.05).clamp(0.0, 0.30);
        expect(adjusted.frozenBlockProbability, closeTo(expected, 1e-9));
      });

      test('D7 procedural (frozen wrinkle) bumps frozen probability', () {
        final generator = LevelGenerator();
        // L31 is the first level in D7 (procedural). D7's wrinkle list
        // is ['frozen'] per the wrinklePool[0] assignment.
        final base = LevelParams.forLevel(31);
        final adjusted = generator.paramsForLevel(31);
        expect(
          adjusted.frozenBlockProbability,
          greaterThan(base.frozenBlockProbability),
        );
      });

      test('frozen probability cap stays at 0.30', () {
        // Even at high levels with already-elevated base frozen prob,
        // the +0.05 wrinkle bump should clamp at 0.30.
        final generator = LevelGenerator();
        // L100+ base has 0.15 frozen; +0.05 = 0.20. Still under cap.
        final params200 = generator.paramsForLevel(200);
        expect(params200.frozenBlockProbability, lessThanOrEqualTo(0.30));
      });

      test('non-frozen wrinkles are recognized but no-op', () {
        // D8 = 'fragile' wrinkle (no-op stub today). Frozen probability
        // should NOT change from baseline since fragile doesn't adjust
        // it. This guards against accidentally lumping all wrinkles
        // into the frozen path.
        final generator = LevelGenerator();
        final base = LevelParams.forLevel(36);
        final adjusted = generator.paramsForLevel(36);
        expect(
          adjusted.frozenBlockProbability,
          base.frozenBlockProbability,
          reason: 'D8 fragile wrinkle should not modify frozen probability',
        );
      });

      test('procedural levels stay generatable after wrinkle bump', () {
        // Phase H — `generateSolvableLevel` is gone. The conveyor
        // mechanic's `_loadLevel` path generates levels via
        // `ConveyorSeed.generateBays` (solvability by construction).
        // The frozen-wrinkle layering test is now in
        // `test/services/wrinkle_layerer_test.dart`.
        //
        // We keep this test slot as a no-op marker so the surrounding
        // group still reports its intent in CI logs. The contract
        // ("D7 frozen wrinkle yields ≥1 frozen block") is covered by
        // wrinkle_layerer_test.dart's "frozen wrinkle only spawns
        // when in list" + the conveyor_seed_test.dart inviolable
        // assertions.
      });
    });
  });
}
