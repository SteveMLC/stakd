import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:warehouse_sort/services/achievement_service.dart';
import 'package:warehouse_sort/services/income_multiplier_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AchievementService catalog (extended warehouse achievements)', () {
    late AchievementService svc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await IncomeMultiplierService().reset();
      await IncomeMultiplierService().init();
      svc = AchievementService();
      await svc.init();
    });

    // ------------------------------------------------------------------
    // (a) The 6 new achievement IDs exist in the service catalog.
    // ------------------------------------------------------------------
    test('all 6 extended warehouse achievement IDs exist in catalog', () {
      const expectedIds = {
        'night_shift_supervisor',
        'zero_damage_dispatch',
        'fleet_foreman',
        'waybill_streak',
        'overtime_payout',
        'union_steward',
      };

      final catalogIds = svc.allAchievements.map((d) => d.id).toSet();
      for (final id in expectedIds) {
        expect(
          catalogIds,
          contains(id),
          reason: 'Catalog must contain new achievement "$id"',
        );
      }
    });

    test('each new achievement has warehouse-flavoured name + description', () {
      const expectedIds = {
        'night_shift_supervisor',
        'zero_damage_dispatch',
        'fleet_foreman',
        'waybill_streak',
        'overtime_payout',
        'union_steward',
      };

      for (final id in expectedIds) {
        final def = svc.allAchievements.firstWhere((d) => d.id == id);
        expect(def.name, isNotEmpty,
            reason: '$id should have a non-empty display name');
        expect(def.description, isNotEmpty,
            reason: '$id should have a non-empty description');
        expect(def.xpReward, greaterThan(0),
            reason: '$id should grant some XP');
      }
    });

    // ------------------------------------------------------------------
    // (b) At least 3 of the 6 appear in incomeBumpAchievementIds.
    // ------------------------------------------------------------------
    test('≥3 of the new achievements grant the +0.25× income bump', () {
      const newIds = {
        'night_shift_supervisor',
        'zero_damage_dispatch',
        'fleet_foreman',
        'waybill_streak',
        'overtime_payout',
        'union_steward',
      };

      final overlap = newIds
          .where(IncomeMultiplierService.incomeBumpAchievementIds.contains)
          .toSet();

      expect(
        overlap.length,
        greaterThanOrEqualTo(3),
        reason:
            'At least 3 of the new achievement IDs must be wired into '
            'IncomeMultiplierService.incomeBumpAchievementIds — got: '
            '$overlap',
      );
    });

    test('all 6 new achievements actually grant +0.25× income bumps', () {
      // Stronger guarantee: the task says "Add all 6 to
      // incomeBumpAchievementIds". Confirm every new ID is wired in.
      const newIds = {
        'night_shift_supervisor',
        'zero_damage_dispatch',
        'fleet_foreman',
        'waybill_streak',
        'overtime_payout',
        'union_steward',
      };
      for (final id in newIds) {
        expect(
          IncomeMultiplierService.incomeBumpAchievementIds,
          contains(id),
          reason: '$id should be in incomeBumpAchievementIds',
        );
      }
    });

    // ------------------------------------------------------------------
    // (c) Legacy progression checker was removed during the rebrand.
    //     Compile-level guarantee comes from this test file not
    //     importing or calling the dead helper. The runtime regression
    //     guard below asserts the dead achievement IDs are absent from
    //     the catalog — a re-introduction would resurrect collisions
    //     with persisted state on devices that played the earlier build.
    // ------------------------------------------------------------------
    // Regression guard: the rebrand purged five achievement IDs from a
    // previous identity. If anyone re-introduces them they'd collide
    // with persisted-state expectations on devices that played an
    // earlier build. Keep the guard; test name by intent rather than
    // dated brand language.
    test('purged legacy achievement IDs stay absent from catalog', () {
      const deadIds = {
        'garden_sprout',
        'paradise_found',
        'blooming_garden',
        'sacred_grove',
        'collectors_pride',
      };
      final catalogIds = svc.allAchievements.map((d) => d.id).toSet();
      for (final id in deadIds) {
        expect(
          catalogIds,
          isNot(contains(id)),
          reason: 'Purged legacy ID "$id" should not be re-introduced',
        );
      }
    });

    // ------------------------------------------------------------------
    // Unlock-logic sanity checks for the new helpers.
    // ------------------------------------------------------------------
    test('checkMachineryOwnership fires fleet_foreman at 4 owned', () {
      expect(svc.getState('fleet_foreman').unlocked, isFalse);

      final none = svc.checkMachineryOwnership(ownedCount: 3);
      expect(none, isEmpty);
      expect(svc.getState('fleet_foreman').unlocked, isFalse);

      final fired = svc.checkMachineryOwnership(ownedCount: 4);
      expect(fired.length, 1);
      expect(fired.first.id, 'fleet_foreman');
      expect(svc.getState('fleet_foreman').unlocked, isTrue);

      // Idempotent — calling again doesn't double-fire.
      final again = svc.checkMachineryOwnership(ownedCount: 5);
      expect(again, isEmpty);
    });

    test('checkPayoutMultiplier fires overtime_payout at ≥5×', () {
      expect(svc.getState('overtime_payout').unlocked, isFalse);

      final under = svc.checkPayoutMultiplier(multiplier: 4.99);
      expect(under, isEmpty);

      final fired = svc.checkPayoutMultiplier(multiplier: 5.0);
      expect(fired.length, 1);
      expect(fired.first.id, 'overtime_payout');
    });

    test('checkUnionSteward needs 2 skins beyond default AND Regional', () {
      // Only skins, no Regional → no fire.
      var result = svc.checkUnionSteward(
        forkliftSkinsOwnedBeyondDefault: 2,
        ownsRegionalTier: false,
      );
      expect(result, isEmpty);

      // Only Regional, 1 skin → no fire.
      result = svc.checkUnionSteward(
        forkliftSkinsOwnedBeyondDefault: 1,
        ownsRegionalTier: true,
      );
      expect(result, isEmpty);

      // Both conditions met → fires.
      result = svc.checkUnionSteward(
        forkliftSkinsOwnedBeyondDefault: 2,
        ownsRegionalTier: true,
      );
      expect(result.length, 1);
      expect(result.first.id, 'union_steward');
    });

    test('checkContractCleared at 02:00 increments night_shift_supervisor',
        () {
      final atTwoAm = DateTime(2026, 5, 14, 2, 0);
      // Need 10 clears to fire.
      for (var i = 0; i < 9; i++) {
        final result = svc.checkContractCleared(nowOverride: atTwoAm);
        expect(result, isEmpty, reason: 'Should not fire before 10 clears');
      }
      final tenth = svc.checkContractCleared(nowOverride: atTwoAm);
      expect(tenth.length, 1);
      expect(tenth.first.id, 'night_shift_supervisor');
    });

    test('checkContractCleared at 12:00 (noon) does NOT count', () {
      final noon = DateTime(2026, 5, 14, 12, 0);
      for (var i = 0; i < 12; i++) {
        final result = svc.checkContractCleared(nowOverride: noon);
        expect(result, isEmpty);
      }
      expect(svc.getState('night_shift_supervisor').unlocked, isFalse);
    });

    test('zero_damage_dispatch fires only when every Local level is no-undo',
        () {
      // Local Contract 1 spans levels 1..5 in the catalog.
      const idx = 0, first = 1, last = 5;
      final allStars = <int, int>{for (var l = first; l <= last; l++) l: 1};

      // Clear levels 1..4 with no undo — not enough yet.
      for (var l = first; l < last; l++) {
        final result = svc.checkContractLevelClear(
          contractIndex: idx,
          levelInContract: l,
          contractFirstLevel: first,
          contractLastLevel: last,
          stars: 1,
          undoUsed: false,
          allLevelStarsInContract: allStars,
          contractTier: 'local',
        );
        expect(result.any((d) => d.id == 'zero_damage_dispatch'), isFalse);
      }

      // Final level no-undo → unlock fires.
      final result = svc.checkContractLevelClear(
        contractIndex: idx,
        levelInContract: last,
        contractFirstLevel: first,
        contractLastLevel: last,
        stars: 1,
        undoUsed: false,
        allLevelStarsInContract: allStars,
        contractTier: 'local',
      );
      expect(result.any((d) => d.id == 'zero_damage_dispatch'), isTrue);
    });

    test('zero_damage_dispatch resets when any level used undo', () {
      const idx = 0, first = 1, last = 5;
      final allStars = <int, int>{for (var l = first; l <= last; l++) l: 1};

      // Level 1: undo used → tracker stays empty for this contract.
      svc.checkContractLevelClear(
        contractIndex: idx,
        levelInContract: first,
        contractFirstLevel: first,
        contractLastLevel: last,
        stars: 1,
        undoUsed: true,
        allLevelStarsInContract: allStars,
        contractTier: 'local',
      );
      // Now clear levels 2..5 no-undo. Level 1 isn't in the no-undo set
      // (because it used undo), so we never get the full span.
      for (var l = first + 1; l <= last; l++) {
        final result = svc.checkContractLevelClear(
          contractIndex: idx,
          levelInContract: l,
          contractFirstLevel: first,
          contractLastLevel: last,
          stars: 1,
          undoUsed: false,
          allLevelStarsInContract: allStars,
          contractTier: 'local',
        );
        expect(result.any((d) => d.id == 'zero_damage_dispatch'), isFalse);
      }
      expect(svc.getState('zero_damage_dispatch').unlocked, isFalse);
    });

    test('waybill_streak fires when every Local level hits 3 stars', () {
      const idx = 0, first = 1, last = 5;
      // Player just 3-starred the last level and all previous are 3-star.
      final allStars = <int, int>{for (var l = first; l <= last; l++) l: 3};

      final result = svc.checkContractLevelClear(
        contractIndex: idx,
        levelInContract: last,
        contractFirstLevel: first,
        contractLastLevel: last,
        stars: 3,
        undoUsed: true, // doesn't matter for waybill_streak
        allLevelStarsInContract: allStars,
        contractTier: 'local',
      );
      expect(result.any((d) => d.id == 'waybill_streak'), isTrue);
    });

    test('waybill_streak does NOT fire if any level is below 3 stars', () {
      const idx = 0, first = 1, last = 5;
      final allStars = <int, int>{
        1: 3, 2: 3, 3: 2, 4: 3, 5: 3, // level 3 only 2-star
      };

      final result = svc.checkContractLevelClear(
        contractIndex: idx,
        levelInContract: last,
        contractFirstLevel: first,
        contractLastLevel: last,
        stars: 3,
        undoUsed: false,
        allLevelStarsInContract: allStars,
        contractTier: 'local',
      );
      expect(result.any((d) => d.id == 'waybill_streak'), isFalse);
    });

    test('regional-tier contracts do NOT fire Local-only achievements', () {
      const idx = 3, first = 16, last = 20;
      final allStars = <int, int>{for (var l = first; l <= last; l++) l: 3};

      final result = svc.checkContractLevelClear(
        contractIndex: idx,
        levelInContract: last,
        contractFirstLevel: first,
        contractLastLevel: last,
        stars: 3,
        undoUsed: false,
        allLevelStarsInContract: allStars,
        contractTier: 'regional',
      );
      expect(result.any((d) => d.id == 'waybill_streak'), isFalse);
      expect(result.any((d) => d.id == 'zero_damage_dispatch'), isFalse);
    });
  });

  group('AchievementService district + tier milestone checks', () {
    late AchievementService svc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      svc = AchievementService();
      // AchievementService is a singleton — mock prefs + init wipes
      // in-memory unlocked-state for the fresh test scope.
      await svc.init();
    });

    test('checkDistrictMilestones(1) fires first_district_cleared', () {
      final result = svc.checkDistrictMilestones(districtNumber: 1);
      expect(result.any((d) => d.id == 'first_district_cleared'), isTrue);
      expect(svc.getState('first_district_cleared').unlocked, isTrue);
    });

    test('checkDistrictMilestones(1) is idempotent on second call', () {
      svc.checkDistrictMilestones(districtNumber: 1);
      final second = svc.checkDistrictMilestones(districtNumber: 1);
      expect(second, isEmpty);
    });

    test('checkDistrictMilestones(2) does NOT fire first_district', () {
      final result = svc.checkDistrictMilestones(districtNumber: 2);
      expect(result, isEmpty);
      expect(svc.getState('first_district_cleared').unlocked, isFalse);
    });

    test('checkDistrictMilestones(4) fires regional_district_cleared', () {
      final result = svc.checkDistrictMilestones(districtNumber: 4);
      expect(result.any((d) => d.id == 'regional_district_cleared'), isTrue);
    });

    test('checkDistrictMilestones(6) still fires regional_district_cleared',
        () {
      final result = svc.checkDistrictMilestones(districtNumber: 6);
      expect(result.any((d) => d.id == 'regional_district_cleared'), isTrue);
    });

    test('checkDistrictMilestones(7) fires procedural_explorer', () {
      final result = svc.checkDistrictMilestones(districtNumber: 7);
      expect(result.any((d) => d.id == 'procedural_explorer'), isTrue);
    });

    test('checkDistrictMilestones(8) does NOT fire procedural_explorer', () {
      final result = svc.checkDistrictMilestones(districtNumber: 8);
      // Only D7 — the FIRST procedural — gets the explorer flag.
      expect(result.any((d) => d.id == 'procedural_explorer'), isFalse);
    });

    test('checkReputationTier(1) fires bronze_promotion', () {
      final result = svc.checkReputationTier(newTierLevel: 1);
      expect(result.any((d) => d.id == 'bronze_promotion'), isTrue);
    });

    test('checkReputationTier(9) fires both bronze and legendary', () {
      // Crossing tier 9 implies the player already passed tier 1; both
      // achievements unlock atomically.
      final result = svc.checkReputationTier(newTierLevel: 9);
      expect(result.any((d) => d.id == 'bronze_promotion'), isTrue);
      expect(result.any((d) => d.id == 'legendary_promotion'), isTrue);
    });

    test('checkReputationTier(8) does NOT fire legendary', () {
      final result = svc.checkReputationTier(newTierLevel: 8);
      // Tiers 1-5 (Bronze, Silver, Gold, Platinum, Diamond) all
      // unlock at tier 8 since the player has crossed them all.
      expect(result.any((d) => d.id == 'bronze_promotion'), isTrue);
      expect(result.any((d) => d.id == 'silver_promotion'), isTrue);
      expect(result.any((d) => d.id == 'gold_promotion'), isTrue);
      expect(result.any((d) => d.id == 'platinum_promotion'), isTrue);
      expect(result.any((d) => d.id == 'diamond_promotion'), isTrue);
      expect(result.any((d) => d.id == 'legendary_promotion'), isFalse);
    });

    test('checkReputationTier(2) fires Bronze + Silver only', () {
      final result = svc.checkReputationTier(newTierLevel: 2);
      expect(result.any((d) => d.id == 'bronze_promotion'), isTrue);
      expect(result.any((d) => d.id == 'silver_promotion'), isTrue);
      expect(result.any((d) => d.id == 'gold_promotion'), isFalse);
    });

    test('checkReputationTier(4) fires Bronze through Platinum', () {
      final result = svc.checkReputationTier(newTierLevel: 4);
      for (final id in [
        'bronze_promotion',
        'silver_promotion',
        'gold_promotion',
        'platinum_promotion',
      ]) {
        expect(result.any((d) => d.id == id), isTrue,
            reason: '$id should unlock at tier 4');
      }
      expect(result.any((d) => d.id == 'diamond_promotion'), isFalse);
    });

    test('checkReputationTier(5) fires Bronze through Diamond', () {
      final result = svc.checkReputationTier(newTierLevel: 5);
      expect(result.any((d) => d.id == 'diamond_promotion'), isTrue);
      expect(result.any((d) => d.id == 'legendary_promotion'), isFalse);
    });

    test('checkReputationTier is idempotent on repeated calls', () {
      final first = svc.checkReputationTier(newTierLevel: 3);
      expect(first, isNotEmpty); // Bronze + Silver + Gold
      final second = svc.checkReputationTier(newTierLevel: 3);
      expect(second, isEmpty); // already unlocked
    });

    test('all 9 milestone achievements exist in catalog', () {
      final ids = svc.allAchievements.map((d) => d.id).toSet();
      expect(ids, contains('first_district_cleared'));
      expect(ids, contains('regional_district_cleared'));
      expect(ids, contains('procedural_explorer'));
      expect(ids, contains('bronze_promotion'));
      expect(ids, contains('silver_promotion'));
      expect(ids, contains('gold_promotion'));
      expect(ids, contains('platinum_promotion'));
      expect(ids, contains('diamond_promotion'));
      expect(ids, contains('legendary_promotion'));
    });

    test('milestone achievements use the warehouse category', () {
      for (final id in [
        'first_district_cleared',
        'regional_district_cleared',
        'procedural_explorer',
        'bronze_promotion',
        'silver_promotion',
        'gold_promotion',
        'platinum_promotion',
        'diamond_promotion',
        'legendary_promotion',
      ]) {
        final def =
            svc.allAchievements.firstWhere((d) => d.id == id);
        expect(def.category, AchievementCategoryExt.warehouse,
            reason: '$id should be warehouse-categorized');
      }
    });

    test('tier reward XP scales with tier level', () {
      final ids = [
        'bronze_promotion',
        'silver_promotion',
        'gold_promotion',
        'platinum_promotion',
        'diamond_promotion',
        'legendary_promotion',
      ];
      int prevXp = 0;
      for (final id in ids) {
        final def =
            svc.allAchievements.firstWhere((d) => d.id == id);
        expect(def.xpReward, greaterThan(prevXp),
            reason: '$id XP reward (${def.xpReward}) should exceed prev ($prevXp)');
        prevXp = def.xpReward;
      }
    });
  });

  group('AchievementCategoryExt (warehouse rename)', () {
    test('garden enum value has been renamed to warehouse', () {
      final names = AchievementCategoryExt.values.map((e) => e.name).toSet();
      expect(names, contains('warehouse'));
      expect(names, isNot(contains('garden')));
    });

    test('warehouse-themed achievements use AchievementCategoryExt.warehouse',
        () {
      final svc = AchievementService();
      // first_shipment was a 'garden'-tagged entry in the legacy catalog.
      final def =
          svc.allAchievements.firstWhere((d) => d.id == 'first_shipment');
      expect(def.category, AchievementCategoryExt.warehouse);
    });
  });
}
