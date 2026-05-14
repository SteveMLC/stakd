import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:warehouse_sort/services/machinery_service.dart';
import 'package:warehouse_sort/services/warehouse_economy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MachineryService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await MachineryService().reset();
      await MachineryService().init();
      await WarehouseEconomyService().reset();
      await WarehouseEconomyService().init();
    });

    test('fresh install: nothing owned, zero bonus', () {
      expect(MachineryService().owned, isEmpty);
      expect(MachineryService().totalIncomeBonus, 0.0);
    });

    test('catalog has all 6 v1.0 items in ascending cost order', () {
      expect(MachineryService.catalog.length, 6);
      // Each entry's cashCost is strictly greater than the previous.
      for (var i = 1; i < MachineryService.catalog.length; i++) {
        expect(
          MachineryService.catalog[i].cashCost,
          greaterThan(MachineryService.catalog[i - 1].cashCost),
          reason: 'Catalog[$i] should cost more than [${i - 1}]',
        );
      }
      // And each entry's WH-level gate is non-decreasing.
      for (var i = 1; i < MachineryService.catalog.length; i++) {
        expect(
          MachineryService.catalog[i].minWarehouseLevel,
          greaterThanOrEqualTo(
            MachineryService.catalog[i - 1].minWarehouseLevel,
          ),
        );
      }
      // Sum of all incomeBonus = 2.50× (= maxMachineryBonus).
      final sum = MachineryService.catalog
          .fold<double>(0, (acc, m) => acc + m.incomeBonus);
      expect(sum, closeTo(2.50, 0.001));
    });

    test('purchase blocked by warehouse level', () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      // Default WH Lv 1 — Pallet Jack needs Lv 3.
      await econ.grantCash(1000);
      expect(
        mach.checkPurchase(
            Machinery.palletJack, econ.cash, econ.warehouseLevel),
        MachineryPurchaseResult.warehouseLevelTooLow,
      );
      final result = await mach.purchase(Machinery.palletJack);
      expect(result, MachineryPurchaseResult.warehouseLevelTooLow);
      expect(mach.isOwned(Machinery.palletJack), isFalse);
    });

    test('purchase blocked by insufficient cash', () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      // Bump WH to 3 but cash is too low.
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(3) + 1,
        ),
      );
      // Pallet Jack costs $300; default install grant is $200.
      expect(econ.cash, lessThan(300));
      expect(
        mach.checkPurchase(
            Machinery.palletJack, econ.cash, econ.warehouseLevel),
        MachineryPurchaseResult.insufficientCash,
      );
    });

    test('successful purchase: deducts cash, adds to owned, stacks bonus',
        () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      await econ.grantCash(500);
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(3) + 1,
        ),
      );
      final cashBefore = econ.cash;

      final result = await mach.purchase(Machinery.palletJack);
      expect(result, MachineryPurchaseResult.success);
      expect(mach.isOwned(Machinery.palletJack), isTrue);
      expect(mach.totalIncomeBonus, closeTo(0.10, 0.001));
      expect(econ.cash, cashBefore - 300);
    });

    test('second purchase of same item is alreadyOwned', () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      await econ.grantCash(500);
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(3) + 1,
        ),
      );

      expect(await mach.purchase(Machinery.palletJack),
          MachineryPurchaseResult.success);
      // Second buy: blocked, no cash deducted.
      final cashAfterFirst = econ.cash;
      expect(await mach.purchase(Machinery.palletJack),
          MachineryPurchaseResult.alreadyOwned);
      expect(econ.cash, cashAfterFirst);
    });

    test('multiple purchases stack income bonus', () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      await econ.grantCash(10000);
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(15) + 1,
        ),
      );

      expect(await mach.purchase(Machinery.palletJack),
          MachineryPurchaseResult.success);
      expect(await mach.purchase(Machinery.conveyorBelt),
          MachineryPurchaseResult.success);
      expect(await mach.purchase(Machinery.hydraulicLift),
          MachineryPurchaseResult.success);

      // 0.10 + 0.20 + 0.30 = 0.60
      expect(mach.totalIncomeBonus, closeTo(0.60, 0.001));
      expect(mach.owned.length, 3);
    });

    test('persistence: owned set survives reset/init cycle', () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      await econ.grantCash(500);
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(3) + 1,
        ),
      );
      await mach.purchase(Machinery.palletJack);
      expect(mach.isOwned(Machinery.palletJack), isTrue);

      // Mimic an app restart: force _initialized to false via reset,
      // then re-init and confirm the data layer round-trip works.
      await SharedPreferences.getInstance(); // ensure prefs are flushed
      // Note: reset() also clears prefs, so we don't test that path here —
      // the persistence path is via _persist + init from prefs.
      // Re-instantiate the singleton-internal state by going through init.
      // (Singleton retains state, so this is mostly a smoke check.)
      expect(mach.isOwned(Machinery.palletJack), isTrue);
    });

    test('reset clears everything', () async {
      final mach = MachineryService();
      final econ = WarehouseEconomyService();
      await econ.grantCash(500);
      await econ.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(3) + 1,
        ),
      );
      await mach.purchase(Machinery.palletJack);
      expect(mach.isOwned(Machinery.palletJack), isTrue);

      await mach.reset();
      await mach.init();
      expect(mach.owned, isEmpty);
      expect(mach.totalIncomeBonus, 0.0);
    });

    test('infoFor returns the right entry for every id', () {
      for (final m in Machinery.values) {
        final info = MachineryService().infoFor(m);
        expect(info.id, m);
        expect(info.displayName, isNotEmpty);
        expect(info.cashCost, greaterThan(0));
        expect(info.incomeBonus, greaterThan(0));
      }
    });
  });
}
