import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_sort/data/local_regional_levels.dart';
import 'package:warehouse_sort/services/business_tier_service.dart';
import 'package:warehouse_sort/services/warehouse_economy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BusinessTierService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await BusinessTierService().reset();
      await WarehouseEconomyService().reset();
    });

    test('Local is always owned + selected by default', () {
      final svc = BusinessTierService();
      expect(svc.isOwned(BusinessTier.local), isTrue);
      expect(svc.selectedTier, BusinessTier.local);
    });

    test('catalog has Local + Regional with correct gates', () {
      final local = BusinessTierService().infoFor(BusinessTier.local);
      expect(local.cashCost, 0);
      expect(local.minWarehouseLevel, 1);
      expect(local.earningsMultiplier, 1.0);

      final regional = BusinessTierService().infoFor(BusinessTier.regional);
      // Lowered $5,000 → $3,000 (2026-05-14 balance patch) to unwall
      // casual-pace players at L15 (audit showed them stalled at
      // ~$2,166 against the prior $5K gate).
      expect(regional.cashCost, 3000);
      expect(regional.minWarehouseLevel, 10);
      expect(regional.earningsMultiplier, 1.5);
    });

    test('checkPurchase: alreadyOwned for Local', () {
      final svc = BusinessTierService();
      expect(
        svc.checkPurchase(BusinessTier.local, 999999, 99),
        PurchaseResult.alreadyOwned,
      );
    });

    test('checkPurchase: warehouseLevelTooLow when WH level < min', () {
      expect(
        BusinessTierService().checkPurchase(BusinessTier.regional, 99999, 1),
        PurchaseResult.warehouseLevelTooLow,
      );
    });

    test('checkPurchase: insufficientCash when WH level fine but cash low', () {
      expect(
        BusinessTierService().checkPurchase(BusinessTier.regional, 100, 15),
        PurchaseResult.insufficientCash,
      );
    });

    test('checkPurchase: success when both gates pass', () {
      expect(
        BusinessTierService().checkPurchase(BusinessTier.regional, 10000, 15),
        PurchaseResult.success,
      );
    });

    test('purchase deducts cash + adds tier + selects', () async {
      final tiers = BusinessTierService();
      final economy = WarehouseEconomyService();
      await tiers.reset();
      await economy.reset();
      await economy.grantCash(6000);

      // Force WH level via XP grant: L10 needs cumulative XP for level 10.
      // For test purposes we directly probe selection-after-purchase via a
      // synthetic XP grant large enough to cross L10.
      await economy.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(10) + 1,
        ),
      );
      expect(economy.warehouseLevel, greaterThanOrEqualTo(10));

      final result = await tiers.purchase(BusinessTier.regional);
      expect(result, PurchaseResult.success);
      expect(tiers.isOwned(BusinessTier.regional), isTrue);
      expect(tiers.selectedTier, BusinessTier.regional);
      expect(economy.cash, 3000); // 6000 - 3000 (post-balance-patch cost)
    });

    test('purchase refuses when warehouse level too low', () async {
      final tiers = BusinessTierService();
      final economy = WarehouseEconomyService();
      await tiers.reset();
      await economy.reset();
      await economy.grantCash(10000);

      final result = await tiers.purchase(BusinessTier.regional);
      expect(result, PurchaseResult.warehouseLevelTooLow);
      expect(tiers.isOwned(BusinessTier.regional), isFalse);
      expect(economy.cash, 10000); // unchanged
    });

    test('multiplierFor returns the tier multiplier', () {
      expect(
        BusinessTierService().multiplierFor(BusinessTier.local),
        1.0,
      );
      expect(
        BusinessTierService().multiplierFor(BusinessTier.regional),
        1.5,
      );
    });
  });
}
