import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_sort/services/cosmetic_service.dart';
import 'package:warehouse_sort/services/warehouse_economy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CosmeticService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CosmeticService().reset();
      await WarehouseEconomyService().reset();
    });

    test('Yellow Standard is owned + selected by default', () {
      final svc = CosmeticService();
      expect(svc.isOwned(ForkliftSkin.yellowStandard), isTrue);
      expect(svc.selectedForklift, ForkliftSkin.yellowStandard);
    });

    test('catalog has 4 skins with correct gates', () {
      expect(CosmeticService.catalog.length, 4);
      final yellow = CosmeticService().infoFor(ForkliftSkin.yellowStandard);
      expect(yellow.cashCost, 0);
      expect(yellow.minWarehouseLevel, 1);

      final red = CosmeticService().infoFor(ForkliftSkin.redSport);
      expect(red.cashCost, 500);
      expect(red.minWarehouseLevel, 15);

      final blue = CosmeticService().infoFor(ForkliftSkin.blueHeavy);
      expect(blue.cashCost, 1500);

      final gold = CosmeticService().infoFor(ForkliftSkin.goldPremium);
      expect(gold.cashCost, 5000);
    });

    test('checkPurchase: warehouseLevelTooLow gates rare skins', () {
      expect(
        CosmeticService().checkPurchase(ForkliftSkin.redSport, 99999, 5),
        CosmeticPurchaseResult.warehouseLevelTooLow,
      );
    });

    test('checkPurchase: insufficientCash when WH level fine', () {
      expect(
        CosmeticService().checkPurchase(ForkliftSkin.redSport, 100, 20),
        CosmeticPurchaseResult.insufficientCash,
      );
    });

    test('checkPurchase: success when both gates pass', () {
      expect(
        CosmeticService().checkPurchase(ForkliftSkin.redSport, 1000, 20),
        CosmeticPurchaseResult.success,
      );
    });

    test('purchase deducts cash + adds to owned + auto-selects', () async {
      final cosmetic = CosmeticService();
      final economy = WarehouseEconomyService();
      await cosmetic.reset();
      await economy.reset();
      await economy.grantCash(1000);
      await economy.awardReward(
        ShipmentReward(
          cash: 0,
          xp: WarehouseEconomyService.cumulativeXpForLevel(15) + 1,
        ),
      );

      final result = await cosmetic.purchase(ForkliftSkin.redSport);
      expect(result, CosmeticPurchaseResult.success);
      expect(cosmetic.isOwned(ForkliftSkin.redSport), isTrue);
      expect(cosmetic.selectedForklift, ForkliftSkin.redSport);
      expect(economy.cash, 500); // 1000 - 500
    });

    test('selectForklift refuses unowned skins', () async {
      final svc = CosmeticService();
      await svc.reset();
      expect(await svc.selectForklift(ForkliftSkin.goldPremium), isFalse);
      expect(svc.selectedForklift, ForkliftSkin.yellowStandard);
    });
  });
}
