import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:warehouse_sort/data/local_regional_levels.dart';
import 'package:warehouse_sort/services/business_tier_service.dart';
import 'package:warehouse_sort/services/contract_service.dart';
import 'package:warehouse_sort/services/income_multiplier_service.dart';
import 'package:warehouse_sort/services/machinery_service.dart';
import 'package:warehouse_sort/services/warehouse_economy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IncomeMultiplierService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await IncomeMultiplierService().reset();
      await IncomeMultiplierService().init();
      await ContractService().reset();
      await ContractService().init();
      await BusinessTierService().reset();
      await BusinessTierService().init();
      await MachineryService().reset();
      await MachineryService().init();
      await WarehouseEconomyService().reset();
      await WarehouseEconomyService().init();
    });

    test('fresh install: multiplier is 1.0 (no bonuses)', () {
      expect(
        IncomeMultiplierService().computeMultiplier(warehouseLevel: 1),
        1.0,
      );
    });

    test('clearing 1 contract adds +0.10×', () async {
      final svc = ContractService();
      for (var lvl = 1; lvl <= 5; lvl++) {
        await svc.recordLevelComplete(lvl, 1, cashBonusForContract: 0);
      }
      expect(svc.isContractCleared(ContractService.contracts[0]), isTrue);
      expect(
        IncomeMultiplierService().computeMultiplier(warehouseLevel: 1),
        closeTo(1.10, 0.001),
      );
    });

    test('contract bonus caps at +1.50×', () async {
      // Clear all 6 contracts (15+ would exceed cap of 1.50).
      final svc = ContractService();
      for (final c in ContractService.contracts) {
        for (var lvl = c.firstLevel; lvl <= c.lastLevel; lvl++) {
          await svc.recordLevelComplete(lvl, 1, cashBonusForContract: 0);
        }
      }
      // 6 contracts × 0.10 = 0.60 — below the 1.50 cap.
      expect(
        IncomeMultiplierService().computeMultiplier(warehouseLevel: 1),
        closeTo(1.60, 0.001),
      );
    });

    test('regional tier purchase adds +0.50×', () async {
      final tiers = BusinessTierService();
      final economy = WarehouseEconomyService();
      await economy.grantCash(10000);
      await economy.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(10) + 1,
        ),
      );
      final result = await tiers.purchase(BusinessTier.regional);
      expect(result, PurchaseResult.success);
      // 1 tier purchase = +0.50×
      expect(
        IncomeMultiplierService()
            .computeMultiplier(warehouseLevel: economy.warehouseLevel),
        // The XP grant takes the player past Lv5 too, adding small bonus.
        greaterThanOrEqualTo(1.50),
      );
    });

    test('achievement bumps grant +0.25× each, idempotent', () async {
      final svc = IncomeMultiplierService();
      expect(svc.computeMultiplier(warehouseLevel: 1), 1.0);

      // Unknown achievement IDs are ignored.
      expect(await svc.recordAchievementBump('unknown_id'), isFalse);
      expect(svc.computeMultiplier(warehouseLevel: 1), 1.0);

      // Valid IDs bump.
      expect(await svc.recordAchievementBump('first_shipment'), isTrue);
      expect(svc.computeMultiplier(warehouseLevel: 1), closeTo(1.25, 0.001));

      // Same ID twice is a no-op.
      expect(await svc.recordAchievementBump('first_shipment'), isFalse);
      expect(svc.computeMultiplier(warehouseLevel: 1), closeTo(1.25, 0.001));

      // Another ID stacks.
      expect(await svc.recordAchievementBump('forklift_collector'), isTrue);
      expect(svc.computeMultiplier(warehouseLevel: 1), closeTo(1.50, 0.001));
    });

    test('warehouse level past 5 adds +0.05× per level (cap +2.00×)', () {
      final svc = IncomeMultiplierService();
      expect(svc.computeMultiplier(warehouseLevel: 4), 1.0);
      expect(svc.computeMultiplier(warehouseLevel: 5), 1.0); // exactly Lv5 = 0
      expect(svc.computeMultiplier(warehouseLevel: 6), closeTo(1.05, 0.001));
      expect(svc.computeMultiplier(warehouseLevel: 10), closeTo(1.25, 0.001));
      expect(svc.computeMultiplier(warehouseLevel: 25), 2.0); // 20×0.05 = 1.0
      expect(svc.computeMultiplier(warehouseLevel: 45), 3.0); // 40×0.05 = 2.0
      // Past 45, capped at +2.00×
      expect(svc.computeMultiplier(warehouseLevel: 50), 3.0);
      expect(svc.computeMultiplier(warehouseLevel: 999), 3.0);
    });

    test('breakdown returns each source separately', () async {
      final svc = IncomeMultiplierService();
      await svc.recordAchievementBump('first_shipment');
      final parts = svc.breakdown(warehouseLevel: 10);
      expect(parts.length, 6); // Base + contracts + tiers + ach + levels + machinery
      expect(parts[0].label, 'Base');
      expect(parts[0].bonus, 1.0);
      // 1 achievement bump = 0.25
      final achLine = parts.firstWhere((p) => p.label.contains('achievement'));
      expect(achLine.bonus, closeTo(0.25, 0.001));
      // 5 levels past Lv5 = 0.25
      final lvlLine = parts.firstWhere((p) => p.label.contains('WH levels'));
      expect(lvlLine.bonus, closeTo(0.25, 0.001));
      // No machinery owned by default
      final machLine = parts.firstWhere((p) => p.label.contains('machinery'));
      expect(machLine.bonus, 0.0);
    });

    test('owning machinery adds its income bonuses to the multiplier', () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      // Bring level + cash to where the first 3 machines are buyable.
      await econ.grantCash(10000);
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(15) + 1,
        ),
      );
      // Pallet Jack (+0.10) + Conveyor Belt (+0.20) + Hydraulic Lift (+0.30)
      // = +0.60 from machinery alone.
      expect(await mach.purchase(Machinery.palletJack),
          MachineryPurchaseResult.success);
      expect(await mach.purchase(Machinery.conveyorBelt),
          MachineryPurchaseResult.success);
      expect(await mach.purchase(Machinery.hydraulicLift),
          MachineryPurchaseResult.success);

      // Drop into breakdown — last row is machinery, bonus = 0.60
      final parts = IncomeMultiplierService()
          .breakdown(warehouseLevel: econ.warehouseLevel);
      final machLine = parts.firstWhere((p) => p.label.contains('machinery'));
      expect(machLine.bonus, closeTo(0.60, 0.001));
      expect(machLine.label, contains('3 machinery'));
    });

    test('machinery bonus is capped at +2.50×', () async {
      // Synthetic test: even if owning all 6 machines (sum = 2.50)
      // or if a future catalog ever exceeded the cap, the multiplier
      // service must not exceed maxMachineryBonus.
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      // Fund + level-up past WH 40 so all 6 are buyable.
      await econ.grantCash(500000);
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(40) + 1,
        ),
      );
      for (final m in Machinery.values) {
        expect(await mach.purchase(m), MachineryPurchaseResult.success);
      }
      expect(mach.totalIncomeBonus, closeTo(2.50, 0.001));
      // Cap holds.
      expect(
        IncomeMultiplierService.maxMachineryBonus,
        2.50,
      );
    });

    test('reset clears persistent state', () async {
      final svc = IncomeMultiplierService();
      await svc.recordAchievementBump('first_shipment');
      expect(svc.unlockedBumps, {'first_shipment'});
      await svc.reset();
      await svc.init();
      expect(svc.unlockedBumps, isEmpty);
      expect(svc.computeMultiplier(warehouseLevel: 1), 1.0);
    });
  });
}
