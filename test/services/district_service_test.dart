import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_sort/services/district_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DistrictService().reset();
    await DistrictService().init();
  });

  group('DistrictService — hand-tuned catalog', () {
    test('exposes 6 hand-tuned districts', () {
      expect(DistrictService.handTunedCount, 6);
      expect(DistrictService.handTunedCatalog.length, 6);
    });

    test('D1 is the free starter district', () {
      final d1 = DistrictService().definitionFor(1);
      expect(d1.number, 1);
      expect(d1.displayName, 'Local Dock');
      expect(d1.unlockCost, 0.0);
      expect(d1.firstLevel, 1);
      expect(d1.lastLevel, 5);
      expect(d1.wrinkles, isEmpty);
      expect(d1.isHandTuned, isTrue);
    });

    test('D3 is the Cold Storage frozen district', () {
      final d3 = DistrictService().definitionFor(3);
      expect(d3.displayName, 'Cold Storage');
      expect(d3.wrinkles, ['frozen']);
      expect(d3.firstLevel, 11);
      expect(d3.lastLevel, 15);
      expect(d3.themeId, 'frost-blue');
    });

    test('hand-tuned districts cover levels 1-30 contiguously', () {
      var expectedFirst = 1;
      for (final d in DistrictService.handTunedCatalog) {
        expect(d.firstLevel, expectedFirst,
            reason: 'D${d.number} should start at $expectedFirst');
        expect(d.lastLevel - d.firstLevel, 4,
            reason: '5-level blocks (last - first = 4)');
        expectedFirst = d.lastLevel + 1;
      }
      expect(DistrictService.handTunedCatalog.last.lastLevel, 30);
    });
  });

  group('DistrictService — procedural composition', () {
    test('D7 is the first procedural district', () {
      final d7 = DistrictService().definitionFor(7);
      expect(d7.isHandTuned, isFalse);
      expect(d7.firstLevel, 31);
      expect(d7.lastLevel, 35);
      expect(d7.unlockCost, DistrictService.proceduralBaseCost);
      expect(d7.themeId, DistrictService.proceduralThemePool.first);
      expect(d7.wrinkles, ['frozen']); // first wrinkle in pool
    });

    test('D8 uses the next theme + next wrinkle', () {
      final d8 = DistrictService().definitionFor(8);
      expect(d8.themeId, DistrictService.proceduralThemePool[1]);
      expect(d8.wrinkles, ['fragile']);
    });

    test('procedural cost curve is exponential 10×', () {
      expect(DistrictService().definitionFor(7).unlockCost, 1_500_000.0);
      expect(DistrictService().definitionFor(8).unlockCost, 15_000_000.0);
      expect(DistrictService().definitionFor(9).unlockCost, 150_000_000.0);
      expect(DistrictService().definitionFor(10).unlockCost, 1_500_000_000.0);
    });

    test('procedural costs scale into quintillions+ without overflow', () {
      // D20 = 1.5M × 10^13 = 1.5e19 — past int max (~9.22e18). Stored
      // as double so no clamp.
      final d20 = DistrictService().definitionFor(20);
      expect(d20.unlockCost, greaterThan(0));
      expect(d20.unlockCost, closeTo(1.5e19, 1e17));
      // D40 = 1.5M × 10^33 = 1.5e39 — deep into infinite-scaling.
      final d40 = DistrictService().definitionFor(40);
      expect(d40.unlockCost, closeTo(1.5e39, 1e37));
    });

    test('procedural theme rotates through the pool', () {
      final poolSize = DistrictService.proceduralThemePool.length;
      // D7 = idx 0, D7+poolSize = idx 0 again
      final dStart = DistrictService().definitionFor(7);
      final dWrap = DistrictService().definitionFor(7 + poolSize);
      expect(dWrap.themeId, dStart.themeId);
    });

    test('wrinkle pool exhausts at D14 then mixes', () {
      // D7-D14 each introduce a new wrinkle (8 wrinkles).
      final d14 = DistrictService().definitionFor(14);
      expect(d14.wrinkles.length, 1);
      expect(d14.wrinkles.first, DistrictService.wrinklePool.last);

      // D15+ mixes 1-2 wrinkles deterministically.
      final d15 = DistrictService().definitionFor(15);
      expect(d15.wrinkles.length, anyOf(1, 2));

      final d20 = DistrictService().definitionFor(20);
      expect(d20.wrinkles.length, anyOf(1, 2));
    });

    test('procedural RP reward scales up gently', () {
      // D7-D16: 1 RP. D17-D26: 2 RP. D27+: 3 RP.
      expect(DistrictService().definitionFor(7).rpReward, 1);
      expect(DistrictService().definitionFor(16).rpReward, 1);
      expect(DistrictService().definitionFor(17).rpReward, 2);
      expect(DistrictService().definitionFor(27).rpReward, 3);
    });

    test('procedural districts have flavor names + taglines', () {
      final d7 = DistrictService().definitionFor(7);
      expect(d7.displayName, contains('District 7'));
      expect(d7.displayName, isNot(contains('Procedural')));
      expect(d7.tagline, isNotEmpty);
    });
  });

  group('DistrictService — districtForLevel', () {
    test('null for non-positive levels', () {
      expect(DistrictService().districtForLevel(0), isNull);
      expect(DistrictService().districtForLevel(-5), isNull);
    });

    test('5-level blocks map correctly', () {
      expect(DistrictService().districtForLevel(1)?.number, 1);
      expect(DistrictService().districtForLevel(5)?.number, 1);
      expect(DistrictService().districtForLevel(6)?.number, 2);
      expect(DistrictService().districtForLevel(15)?.number, 3);
      expect(DistrictService().districtForLevel(30)?.number, 6);
      expect(DistrictService().districtForLevel(31)?.number, 7);
      expect(DistrictService().districtForLevel(50)?.number, 10);
      expect(DistrictService().districtForLevel(100)?.number, 20);
    });
  });

  group('DistrictService — unlock state', () {
    test('fresh install has only D1 unlocked', () {
      expect(DistrictService().isUnlocked(1), isTrue);
      expect(DistrictService().isUnlocked(2), isFalse);
      expect(DistrictService().highestUnlocked, 1);
      expect(DistrictService().highestCleared, 0);
    });

    test('canUnlock requires the prior district cleared', () {
      // D2 requires D1 cleared first.
      expect(DistrictService().canUnlock(number: 2, currentCash: 0), isFalse);
    });

    test('canUnlock for hand-tuned needs only prior clear (no cash)', () async {
      await DistrictService().markCleared(1);
      expect(DistrictService().canUnlock(number: 2, currentCash: 0),
          isFalse); // already auto-unlocked
      expect(DistrictService().isUnlocked(2), isTrue);
    });

    test('canUnlock for procedural needs prior clear AND cash', () async {
      // Force-clear D1-D6 to get to D7's gate.
      for (var n = 1; n <= 6; n++) {
        await DistrictService().markCleared(n);
      }
      // Auto-unlock past hand-tuned doesn't trigger — D7 must be paid.
      expect(DistrictService().isUnlocked(7), isFalse);
      // Without cash, can't unlock.
      expect(DistrictService().canUnlock(number: 7, currentCash: 1_000_000),
          isFalse);
      // With cash, can.
      expect(DistrictService().canUnlock(number: 7, currentCash: 1_500_000),
          isTrue);
    });

    test('markCleared auto-unlocks the next hand-tuned district', () async {
      await DistrictService().markCleared(1);
      expect(DistrictService().isUnlocked(2), isTrue);
      await DistrictService().markCleared(2);
      expect(DistrictService().isUnlocked(3), isTrue);
    });

    test('markCleared does NOT auto-unlock past hand-tuned', () async {
      for (var n = 1; n <= 6; n++) {
        await DistrictService().markCleared(n);
      }
      expect(DistrictService().isCleared(6), isTrue);
      expect(DistrictService().isUnlocked(7), isFalse);
    });

    test('markCleared returns the RP reward', () async {
      final rp = await DistrictService().markCleared(1);
      expect(rp, 1);
    });

    test('markCleared is idempotent', () async {
      final first = await DistrictService().markCleared(1);
      final second = await DistrictService().markCleared(1);
      expect(first, 1);
      expect(second, 0);
    });

    test('unlock adds to set + persists', () async {
      await DistrictService().unlock(7);
      expect(DistrictService().isUnlocked(7), isTrue);
    });
  });

  group('DistrictService — onLevelComplete flow', () {
    test('non-final-level returns 0 RP', () async {
      final rp = await DistrictService().onLevelComplete(
        level: 3,
        everyLevelInDistrictHasStar: true,
      );
      expect(rp, 0);
      expect(DistrictService().isCleared(1), isFalse);
    });

    test('final level with all stars triggers clear + RP', () async {
      final rp = await DistrictService().onLevelComplete(
        level: 5,
        everyLevelInDistrictHasStar: true,
      );
      expect(rp, 1);
      expect(DistrictService().isCleared(1), isTrue);
    });

    test('final level WITHOUT all stars does NOT clear', () async {
      final rp = await DistrictService().onLevelComplete(
        level: 5,
        everyLevelInDistrictHasStar: false,
      );
      expect(rp, 0);
      expect(DistrictService().isCleared(1), isFalse);
    });
  });

  group('DistrictService — nextToUnlock + highest queries', () {
    test('fresh install nextToUnlock is D2', () {
      expect(DistrictService().nextToUnlock.number, 2);
    });

    test('after D1 cleared + D2 cleared, nextToUnlock is D3', () async {
      await DistrictService().markCleared(1);
      await DistrictService().markCleared(2);
      expect(DistrictService().highestUnlocked, 3);
      expect(DistrictService().nextToUnlock.number, 4);
    });

    test('highestCleared tracks the max district number cleared', () async {
      await DistrictService().markCleared(1);
      await DistrictService().markCleared(2);
      await DistrictService().markCleared(3);
      expect(DistrictService().highestCleared, 3);
    });
  });

  group('DistrictService — infinite scaling sanity', () {
    test('D100 composes without error', () {
      final d100 = DistrictService().definitionFor(100);
      expect(d100.number, 100);
      expect(d100.firstLevel, 496);
      expect(d100.lastLevel, 500);
      expect(d100.wrinkles, hasLength(anyOf(1, 2)));
      expect(d100.themeId, isNotEmpty);
    });

    test('District definitions are deterministic per N', () {
      // Same N twice should produce identical results.
      final a = DistrictService().definitionFor(23);
      final b = DistrictService().definitionFor(23);
      expect(a.themeId, b.themeId);
      expect(a.wrinkles, b.wrinkles);
      expect(a.displayName, b.displayName);
      expect(a.unlockCost, b.unlockCost);
    });
  });
}
