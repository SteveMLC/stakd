// Visual-capture integration test — walks Warehouse Sort from a clean
// boot through the home screen, into a contract, into a level, plays a
// move, hits completion overlay, then quits. Inserts long pauses at
// each interesting visual state so a sidecar screenshot loop can grab
// in-game frames from outside the test process.
//
// Why this exists: Walt has no local accessibility permission to drive
// the simulator via cliclick/osascript, and the previous `flutter run`
// path required Steve to tap into a level manually. This test gives
// Walt a fully-automated path to put the app into any visual state and
// capture screenshots via `xcrun simctl io ... screenshot` (which does
// NOT require accessibility).
//
// Pair with tools/visual_capture.sh which runs this test alongside a
// 1Hz simctl-screenshot loop, then tags each frame with the timestamp
// of the state marker printed by this test.
//
// Run:
//   flutter test integration_test/visual_capture_test.dart \
//     -d "8C01668E-EF11-43A9-8448-E276C07C1919" --timeout=4x
//
// Or invoke the orchestrated capture:
//   bash tools/visual_capture.sh

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:warehouse_sort/app.dart';
import 'package:warehouse_sort/models/game_state.dart';
import 'package:warehouse_sort/services/audio_service.dart';
import 'package:warehouse_sort/services/business_tier_service.dart';
import 'package:warehouse_sort/services/contract_service.dart';
import 'package:warehouse_sort/services/cosmetic_service.dart';
import 'package:warehouse_sort/services/currency_service.dart';
import 'package:warehouse_sort/services/district_service.dart';
import 'package:warehouse_sort/services/iap_service.dart';
import 'package:warehouse_sort/services/hydraulic_pressure_service.dart';
import 'package:warehouse_sort/services/income_multiplier_service.dart';
import 'package:warehouse_sort/services/machinery_service.dart';
import 'package:warehouse_sort/services/power_up_service.dart';
import 'package:warehouse_sort/services/reputation_service.dart';
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
  await HydraulicPressureService().reset();
  await HydraulicPressureService().init();
  await ReputationService().reset();
  await ReputationService().init();
  await DistrictService().reset();
  await DistrictService().init();
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
      ChangeNotifierProvider.value(value: HydraulicPressureService()),
      ChangeNotifierProvider.value(value: ReputationService()),
      ChangeNotifierProvider.value(value: DistrictService()),
    ],
    child: const WarehouseSortApp(),
  );
}

/// Hold the app at the current pumped state for `seconds` real-time
/// seconds so a sidecar screenshot loop can capture the frame. Print
/// a state marker before + after for the orchestrator to align frames.
Future<void> _holdForCapture(
  WidgetTester tester,
  String stateName, {
  int seconds = 3,
}) async {
  // ignore: avoid_print
  print('VISUAL_CAPTURE_STATE_BEGIN: $stateName');
  // Keep pumping frames so animations continue + screenshot has fresh
  // content (otherwise we'd just see one frozen frame). 60 fps pumps.
  final frames = seconds * 60;
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  // ignore: avoid_print
  print('VISUAL_CAPTURE_STATE_END: $stateName');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walk to gameplay capturing key states', (tester) async {
    await _bootServices();
    await tester.pumpWidget(_pumpedApp());

    // Splash → home: ~2.4s of splash animation + 1s of home settle.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // ------------------ state 1: home with power-ups (NOT visible
    // because power-ups only show on game screen — capture the home
    // anyway for regression baseline). ------------------
    await _holdForCapture(tester, 'home');

    // Dismiss Daily Rewards if it popped.
    final claim = find.textContaining('CLAIM');
    if (claim.evaluate().isNotEmpty) {
      await tester.tap(claim.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    // Tap PLAY → contracts.
    await tester.tap(find.text('PLAY'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // ------------------ state 2: contracts screen ------------------
    await _holdForCapture(tester, 'contracts');

    // Tap PLAY NEXT to start level 1.
    final playNext = find.text('PLAY NEXT');
    if (playNext.evaluate().isNotEmpty) {
      await tester.tap(playNext.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    // ------------------ state 3: in-game (the goal — color crates
    // + power-up bar + HUD + wrinkle pictogram all visible) -----
    await _holdForCapture(tester, 'in_game', seconds: 6);

    // Skip tutorial if present.
    final skipTutorial = find.text('Skip Tutorial');
    if (skipTutorial.evaluate().isNotEmpty) {
      await tester.tap(skipTutorial, warnIfMissed: false);
      await tester.pumpAndSettle();
      await _holdForCapture(tester, 'in_game_after_tutorial', seconds: 4);
    }

    // We don't assert anything — this is a capture-only test. The
    // mvp_walkthrough_test handles correctness assertions.
  });
}
