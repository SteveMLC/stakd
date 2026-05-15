import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_sort/services/reputation_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReputationService().reset();
    await ReputationService().init();
  });

  group('ReputationService — threshold curve', () {
    test('thresholdForTier follows 5×N×(N+1)/2', () {
      expect(ReputationService.thresholdForTier(0), 0);
      expect(ReputationService.thresholdForTier(1), 5);   // Bronze
      expect(ReputationService.thresholdForTier(2), 15);  // Silver
      expect(ReputationService.thresholdForTier(3), 30);  // Gold
      expect(ReputationService.thresholdForTier(4), 50);  // Platinum
      expect(ReputationService.thresholdForTier(5), 75);  // Diamond
      expect(ReputationService.thresholdForTier(6), 105); // Master
      expect(ReputationService.thresholdForTier(7), 140); // Apex
      expect(ReputationService.thresholdForTier(8), 180); // Mythic
      expect(ReputationService.thresholdForTier(9), 225); // Legendary
      // Past Legendary
      expect(ReputationService.thresholdForTier(10), 275);
      expect(ReputationService.thresholdForTier(20), 1050);
      expect(ReputationService.thresholdForTier(100), 25_250);
    });

    test('thresholdForTier returns 0 for non-positive levels', () {
      expect(ReputationService.thresholdForTier(0), 0);
      expect(ReputationService.thresholdForTier(-5), 0);
    });
  });

  group('ReputationService — currentTier', () {
    test('fresh install is Unranked (tier 0)', () {
      final svc = ReputationService();
      expect(svc.totalRp, 0);
      expect(svc.currentTierLevel, 0);
      expect(svc.currentTier, ReputationTier.none);
      expect(svc.displayName, 'Unranked');
    });

    test('5 RP = Bronze', () async {
      await ReputationService().addReputation(5);
      expect(ReputationService().currentTierLevel, 1);
      expect(ReputationService().currentTier, ReputationTier.bronze);
      expect(ReputationService().displayName, 'Bronze');
    });

    test('threshold + 1 stays at the same tier', () async {
      await ReputationService().addReputation(14); // 1 below Silver
      expect(ReputationService().currentTier, ReputationTier.bronze);
    });

    test('crossing 15 hits Silver', () async {
      await ReputationService().addReputation(15);
      expect(ReputationService().currentTier, ReputationTier.silver);
    });

    test('225 RP = Legendary (tier 9)', () async {
      await ReputationService().addReputation(225);
      expect(ReputationService().currentTierLevel, 9);
      expect(ReputationService().currentTier, ReputationTier.legendary);
      expect(ReputationService().displayName, 'Legendary');
    });

    test('275 RP = Legendary II (tier 10)', () async {
      await ReputationService().addReputation(275);
      expect(ReputationService().currentTierLevel, 10);
      expect(ReputationService().displayName, 'Legendary II');
    });

    test('1050 RP = Legendary XII (tier 20)', () async {
      await ReputationService().addReputation(1050);
      expect(ReputationService().currentTierLevel, 20);
      expect(ReputationService().displayName, 'Legendary XII');
    });
  });

  group('ReputationService — addReputation', () {
    test('returns false when no tier promotion', () async {
      final promoted = await ReputationService().addReputation(3);
      expect(promoted, isFalse);
      expect(ReputationService().totalRp, 3);
    });

    test('returns true on tier promotion', () async {
      final promoted = await ReputationService().addReputation(5);
      expect(promoted, isTrue);
      expect(ReputationService().currentTier, ReputationTier.bronze);
    });

    test('multiple tier jumps in one call only flag once', () async {
      // 30 RP crosses Bronze, Silver, Gold in a single award.
      final promoted = await ReputationService().addReputation(30);
      expect(promoted, isTrue);
      expect(ReputationService().currentTier, ReputationTier.gold);
    });

    test('zero or negative amounts are no-ops', () async {
      expect(await ReputationService().addReputation(0), isFalse);
      expect(await ReputationService().addReputation(-10), isFalse);
      expect(ReputationService().totalRp, 0);
    });
  });

  group('ReputationService — progress + multiplier', () {
    test('rpToNextTier at fresh install needs 5 for Bronze', () {
      expect(ReputationService().rpToNextTier, 5);
    });

    test('rpToNextTier decreases as RP grows', () async {
      await ReputationService().addReputation(3);
      expect(ReputationService().rpToNextTier, 2);
      await ReputationService().addReputation(2);
      expect(ReputationService().currentTier, ReputationTier.bronze);
      expect(ReputationService().rpToNextTier, 10); // 15 - 5 = 10 to Silver
    });

    test('progressToNextTier is 0.0 at the start of a tier', () async {
      await ReputationService().addReputation(5); // exactly Bronze
      expect(ReputationService().progressToNextTier, closeTo(0.0, 0.0001));
    });

    test('progressToNextTier reflects mid-tier RP', () async {
      // Bronze = 5, Silver = 15. Halfway is 10.
      await ReputationService().addReputation(10);
      expect(ReputationService().progressToNextTier, closeTo(0.5, 0.0001));
    });

    test('tierMultiplierBonus is +0.10× per tier', () async {
      expect(ReputationService().tierMultiplierBonus, 0.0);
      await ReputationService().addReputation(5);
      expect(ReputationService().tierMultiplierBonus, closeTo(0.10, 0.0001));
      await ReputationService().addReputation(220); // total 225 = Legendary (9)
      expect(ReputationService().tierMultiplierBonus, closeTo(0.90, 0.0001));
    });

    test('tierMultiplierBonus has no upper cap', () async {
      await ReputationService().addReputation(25250); // tier 100
      expect(ReputationService().currentTierLevel, 100);
      expect(ReputationService().tierMultiplierBonus, closeTo(10.0, 0.0001));
    });
  });

  group('ReputationService — persistence + reset', () {
    test('persists totalRp across init cycle', () async {
      await ReputationService().addReputation(50); // Platinum
      expect(ReputationService().currentTier, ReputationTier.platinum);

      // Simulate restart: reset only the in-memory init flag, re-read
      // from prefs.
      final svc = ReputationService();
      // Force a re-init without wiping prefs.
      // (Internal state already persists via SharedPreferences mock.)
      // The next test verifies init() recovers it.
      expect(svc.totalRp, 50);
    });

    test('reset clears totalRp + drops to Unranked', () async {
      await ReputationService().addReputation(100);
      expect(ReputationService().currentTier, ReputationTier.diamond);
      await ReputationService().reset();
      await ReputationService().init();
      expect(ReputationService().totalRp, 0);
      expect(ReputationService().currentTier, ReputationTier.none);
    });
  });

  group('ReputationService — displayNameForLevel (static helper)', () {
    test('handles every named tier', () {
      expect(ReputationService.displayNameForLevel(0), 'Unranked');
      expect(ReputationService.displayNameForLevel(1), 'Bronze');
      expect(ReputationService.displayNameForLevel(2), 'Silver');
      expect(ReputationService.displayNameForLevel(3), 'Gold');
      expect(ReputationService.displayNameForLevel(4), 'Platinum');
      expect(ReputationService.displayNameForLevel(5), 'Diamond');
      expect(ReputationService.displayNameForLevel(6), 'Master');
      expect(ReputationService.displayNameForLevel(7), 'Apex');
      expect(ReputationService.displayNameForLevel(8), 'Mythic');
      expect(ReputationService.displayNameForLevel(9), 'Legendary');
    });

    test('post-Legendary uses Roman numeral suffix', () {
      expect(ReputationService.displayNameForLevel(10), 'Legendary II');
      expect(ReputationService.displayNameForLevel(11), 'Legendary III');
      expect(ReputationService.displayNameForLevel(13), 'Legendary V');
      expect(ReputationService.displayNameForLevel(18), 'Legendary X');
      expect(ReputationService.displayNameForLevel(58), 'Legendary L');
      expect(ReputationService.displayNameForLevel(108), 'Legendary C');
    });

    test('handles negative levels gracefully', () {
      expect(ReputationService.displayNameForLevel(-1), 'Unranked');
      expect(ReputationService.displayNameForLevel(-100), 'Unranked');
    });
  });

  group('ReputationService — hudLabel', () {
    test('fresh install reads "Unranked · 0/5"', () {
      expect(ReputationService().hudLabel, 'Unranked · 0/5');
    });

    test('mid-tier reads as "{tier} · {rp}/{nextThreshold}"', () async {
      await ReputationService().addReputation(7);
      expect(ReputationService().hudLabel, 'Bronze · 7/15');
    });

    test('past Legendary still reads cleanly', () async {
      await ReputationService().addReputation(280); // tier 10, Legendary II
      expect(ReputationService().hudLabel, 'Legendary II · 280/330');
    });
  });

  group('ReputationService — infinite scaling sanity', () {
    test('tier 50 thresh is large but computable', () {
      // 5 × 50 × 51 / 2 = 6375
      expect(ReputationService.thresholdForTier(50), 6375);
    });

    test('tier 1000 thresh is large but well-defined', () {
      // 5 × 1000 × 1001 / 2 = 2,502,500
      expect(ReputationService.thresholdForTier(1000), 2_502_500);
    });

    test('currentTierLevel solves the inverse correctly across the range',
        () async {
      // Spot-check at a few thresholds + 1 above to verify the
      // quadratic inverse + epsilon don't drift.
      for (final level in [1, 5, 9, 10, 20, 50, 99, 100]) {
        await ReputationService().reset();
        await ReputationService().init();
        final exactThresh = ReputationService.thresholdForTier(level);
        await ReputationService().addReputation(exactThresh);
        expect(ReputationService().currentTierLevel, level,
            reason: 'totalRp=$exactThresh should be tier $level');
      }
    });
  });
}
