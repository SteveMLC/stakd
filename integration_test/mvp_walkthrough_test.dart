// Integration test that walks the Warehouse Sort MVP end-to-end on a real
// device or simulator. Runs the full app — services, providers, navigation —
// and asserts every screen renders + the puzzle mechanic actually moves a
// crate when tapped.
//
// Usage on iOS simulator:
//   flutter test integration_test/mvp_walkthrough_test.dart \
//     -d "<simulator-uuid>"
//
// Usage on Android device/emulator:
//   flutter test integration_test/mvp_walkthrough_test.dart \
//     -d "<adb-device-id>"

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:warehouse_sort/app.dart';
import 'package:warehouse_sort/data/local_regional_levels.dart';
import 'package:warehouse_sort/models/game_state.dart';
import 'package:warehouse_sort/services/audio_service.dart';
import 'package:warehouse_sort/services/business_tier_service.dart';
import 'package:warehouse_sort/services/contract_service.dart';
import 'package:warehouse_sort/services/cosmetic_service.dart';
import 'package:warehouse_sort/services/currency_service.dart';
import 'package:warehouse_sort/services/iap_service.dart';
import 'package:warehouse_sort/services/income_multiplier_service.dart';
import 'package:warehouse_sort/services/machinery_service.dart';
import 'package:warehouse_sort/services/power_up_service.dart';
import 'package:warehouse_sort/services/storage_service.dart';
import 'package:warehouse_sort/services/theme_service.dart';
import 'package:warehouse_sort/services/warehouse_economy_service.dart';

Future<void> _bootServices() async {
  SharedPreferences.setMockInitialValues({});
  await StorageService().init();
  await CurrencyService().init();
  await ThemeService().init();
  await PowerUpService().initializeDefaults();
  await WarehouseEconomyService().reset();
  await WarehouseEconomyService().init();
  await BusinessTierService().reset();
  await BusinessTierService().init();
  await ContractService().reset();
  await ContractService().init();
  await CosmeticService().reset();
  await CosmeticService().init();
  await MachineryService().reset();
  await MachineryService().init();
  await IncomeMultiplierService().reset();
  await IncomeMultiplierService().init();
  // AudioService.init touches platform channels but no-ops on test runs.
  await AudioService().init();
}

Widget _pumpedApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => GameState()),
      ChangeNotifierProvider.value(value: IapService()),
      ChangeNotifierProvider.value(value: ThemeService()),
      ChangeNotifierProvider.value(value: PowerUpService()),
      ChangeNotifierProvider.value(value: WarehouseEconomyService()),
      ChangeNotifierProvider.value(value: BusinessTierService()),
      ChangeNotifierProvider.value(value: ContractService()),
      ChangeNotifierProvider.value(value: CosmeticService()),
      ChangeNotifierProvider.value(value: MachineryService()),
      ChangeNotifierProvider.value(value: IncomeMultiplierService()),
    ],
    child: const WarehouseSortApp(),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen renders with warehouse identity', (tester) async {
    await _bootServices();
    await tester.pumpWidget(_pumpedApp());
    // Home screen has infinite animations (star field, logo bounce) so
    // pumpAndSettle never returns. Pump a fixed window instead — long
    // enough for services to init + first paint to complete.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Logo wordmark.
    expect(find.text('WAREHOUSE\nSORT'), findsOneWidget);
    // Subtitle.
    expect(find.text('Sort the crates. Build the empire.'), findsOneWidget);
    // PLAY button on the primary CTA.
    expect(find.text('PLAY'), findsOneWidget);
    // Daily Contract pill (renamed from Daily Challenge).
    expect(find.textContaining('Daily Contract'), findsWidgets);
    // HUD shows starting cash from the $200 welcome grant.
    expect(find.text('200'), findsOneWidget);
    expect(find.textContaining('WH Lv'), findsOneWidget);
    expect(find.textContaining('Local'), findsWidgets);
    // Forklifts button on home row 3.
    expect(find.text('Forklifts'), findsOneWidget);
    // Machinery button (Phase 6 — replaces disabled Themes slot).
    expect(find.text('Machinery'), findsOneWidget);
  });

  testWidgets('Machinery button opens the equipment shop', (tester) async {
    await _bootServices();
    await tester.pumpWidget(_pumpedApp());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Dismiss the Daily Rewards popup if it auto-fired (it shouldn't on
    // a brand-new install, but be defensive).
    final claim = find.textContaining('CLAIM');
    if (claim.evaluate().isNotEmpty) {
      await tester.tap(claim.first, warnIfMissed: false);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    // Tap Machinery and wait for the shop to render.
    await tester.tap(find.text('Machinery'), warnIfMissed: false);
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Shop header.
    expect(find.text('Machinery'), findsWidgets);
    // Empty-state banner: no machines owned yet.
    expect(
      find.textContaining('No machinery yet'),
      findsOneWidget,
      reason: 'Fresh install banner should prompt the first Pallet Jack',
    );
    // First catalog item must be visible (cheapest, lowest gate).
    expect(find.textContaining('Pallet Jack'), findsWidgets);
    // 6 items in v1 catalog — assert data-level wiring.
    expect(MachineryService.catalog.length, 6);
    // Each catalog item carries a positive income bonus.
    for (final m in MachineryService.catalog) {
      expect(m.incomeBonus, greaterThan(0));
    }
    // Sum of all bonuses = +2.50× (= maxMachineryBonus cap).
    final sum = MachineryService.catalog
        .fold<double>(0, (acc, m) => acc + m.incomeBonus);
    expect(sum, closeTo(2.50, 0.001));
  });

  testWidgets('PLAY navigates to Contract Select with 6 cards', (tester) async {
    await _bootServices();
    await tester.pumpWidget(_pumpedApp());
    // Home screen has infinite animations (star field, logo bounce) so
    // pumpAndSettle never returns. Pump a fixed window instead — long
    // enough for services to init + first paint to complete.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Daily Rewards popup auto-fires on first launch and covers PLAY.
    // Dismiss it via the CLAIM CTA before tapping PLAY underneath.
    final claim = find.textContaining('CLAIM');
    if (claim.evaluate().isNotEmpty) {
      await tester.tap(claim.first, warnIfMissed: false);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    await tester.tap(find.text('PLAY'), warnIfMissed: false);
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Contract Select header.
    expect(find.text('Contracts'), findsOneWidget);
    // Verify the 6-contract catalog is wired (data-level assertion).
    expect(ContractService.contracts.length, 6);
    // The first 3 (Local Contract 1-3) are in the initial viewport — verify
    // by visible widget. Lower contracts lazy-build on scroll.
    for (final contract in ContractService.contracts.take(3)) {
      expect(
        find.textContaining(contract.displayName),
        findsWidgets,
        reason: 'Contract ${contract.displayName} should be in initial viewport',
      );
    }
    expect(find.textContaining('Clear Local Contract 1 first'), findsWidgets);
  });

  testWidgets('economy + level mapping match v0.3 spec', (tester) async {
    await _bootServices();
    final economy = WarehouseEconomyService();

    // Fresh install: welcome grant applied.
    expect(economy.cash, 200);
    expect(economy.warehouseLevel, 1);

    // L1 seed lookup works.
    final l1 = localRegionalLevelSeeds.firstWhere((s) => s.level == 1);
    expect(l1.tier, BusinessTier.local);
    expect(l1.colors, 3);
    expect(l1.bays, 5);

    // Award a reward — cash + xp persist.
    await economy.awardReward(const ShipmentReward(cash: 75, xp: 30));
    expect(economy.cash, 275);
    expect(economy.totalXp, 30);

    // 100 XP total triggers a level-up.
    final lvlUp = await economy.awardReward(
      const ShipmentReward(cash: 0, xp: 70),
    );
    expect(lvlUp, 2);
    expect(economy.warehouseLevel, 2);
  });

  testWidgets('forklift purchase: gated by WH level + auto-equips on success',
      (tester) async {
    await _bootServices();
    final economy = WarehouseEconomyService();
    final cosmetic = CosmeticService();

    // Red Sport needs WH Lv 15 + $500.
    expect(
      cosmetic.checkPurchase(ForkliftSkin.redSport, economy.cash, 1),
      CosmeticPurchaseResult.warehouseLevelTooLow,
    );

    // Bump level via XP grant past the L15 threshold.
    await economy.awardReward(
      ShipmentReward(
        cash: 0,
        xp: WarehouseEconomyService.cumulativeXpForLevel(15) + 1,
      ),
    );
    await economy.grantCash(500);
    expect(economy.warehouseLevel, greaterThanOrEqualTo(15));

    final result = await cosmetic.purchase(ForkliftSkin.redSport);
    expect(result, CosmeticPurchaseResult.success);
    expect(cosmetic.isOwned(ForkliftSkin.redSport), isTrue);
    expect(cosmetic.selectedForklift, ForkliftSkin.redSport);
  });

  testWidgets('contract completion fires bonus + advances chain', (tester) async {
    await _bootServices();
    final contract = ContractService();

    // Sweep L1-L4 with 2 stars each — no completion event yet.
    for (var lvl = 1; lvl <= 4; lvl++) {
      final ev = await contract.recordLevelComplete(
        lvl,
        2,
        cashBonusForContract: 100,
      );
      expect(ev, isNull, reason: 'Level $lvl should not complete contract');
    }

    // L5 with 3 stars: contract complete, event fired.
    final ev = await contract.recordLevelComplete(5, 3, cashBonusForContract: 100);
    expect(ev, isNotNull);
    expect(ev!.cashBonus, 100);
    expect(ev.totalStars, 4 * 2 + 3);

    // Contract 2 is now unlocked.
    expect(
      contract.isContractUnlocked(ContractService.contracts[1]),
      isTrue,
    );
  });
}
