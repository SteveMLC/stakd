import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/game_state.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';
import 'services/ad_service.dart';
import 'services/review_service.dart';
import 'services/iap_service.dart';
import 'services/achievement_service.dart';
import 'services/theme_service.dart';
import 'services/currency_service.dart';
import 'services/leaderboard_service.dart';
import 'services/power_up_service.dart';
import 'services/stats_service.dart';
import 'services/warehouse_economy_service.dart';
import 'services/business_tier_service.dart';
import 'services/contract_service.dart';
import 'services/cosmetic_service.dart';
import 'services/income_multiplier_service.dart';
import 'services/machinery_service.dart';
import 'app.dart';

/// Cap how long any single critical service init can block boot. If we
/// hit this, the service initialises lazily afterwards and the app
/// renders the home screen anyway. Without this guard, a misbehaving
/// platform channel (e.g. AdMob, StoreKit) freezes the splash forever.
const _kInitTimeout = Duration(seconds: 4);

Future<void> _safeInit(String name, Future<void> Function() fn) async {
  try {
    await fn().timeout(_kInitTimeout);
  } catch (e) {
    debugPrint('[boot] $name init failed/timed out: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force semantics tree on web so headless test harnesses (playwright,
  // chromedriver) can query buttons by accessibility label rather than
  // pixel coordinates. Costs a small bundle-size bump (~tens of KB).
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Critical path: only the services the home screen and its widgets
  // actually read on first frame. Parallelise so total wall time is
  // bound by the slowest individual init (typically <100ms).
  await Future.wait([
    _safeInit('StorageService', () => StorageService().init()),
    _safeInit('CurrencyService', () => CurrencyService().init()),
    _safeInit('ThemeService', () => ThemeService().init()),
    _safeInit('AchievementService', () => AchievementService().init()),
    _safeInit('PowerUpService', () => PowerUpService().initializeDefaults()),
    _safeInit('WarehouseEconomyService', () => WarehouseEconomyService().init()),
    _safeInit('BusinessTierService', () => BusinessTierService().init()),
    _safeInit('ContractService', () => ContractService().init()),
    _safeInit('CosmeticService', () => CosmeticService().init()),
    _safeInit('MachineryService', () => MachineryService().init()),
    _safeInit('IncomeMultiplierService', () => IncomeMultiplierService().init()),
    _safeInit('LeaderboardService', () => LeaderboardService().init()),
    _safeInit('StatsService', () => StatsService().init()),
  ]);

  // Apply saved audio prefs synchronously so the AudioService init below
  // picks them up. Reads cached SharedPreferences via StorageService.
  final audioService = AudioService();
  audioService.setSoundEnabled(StorageService().getSoundEnabled());
  audioService.setMusicEnabled(StorageService().getMusicEnabled());

  // Background path: services that touch flaky platform channels
  // (AdMob, StoreKit, AVAudioSession, sim networking). They can take
  // their time finishing — the home screen paints first.
  unawaited(() async {
    await _safeInit('AudioService', () => AudioService().init());
    // Kick the warehouse ambient drone (64s looped track) once the
    // service has settled. Doing it here — outside any widget's
    // initState — keeps the audioplayers FramePositionUpdater's
    // frame callback from leaking into integration-test tear-down
    // (tests bypass main, so the music never starts in tests).
    AudioService().startMusic();
  }());
  unawaited(_safeInit('AdService', () => AdService().init()));
  unawaited(_safeInit('IapService', () => IapService().init()));
  unawaited(() async {
    final prefs = await SharedPreferences.getInstance();
    await _safeInit('ReviewService', () => ReviewService().init(prefs));
    await _safeInit(
        'ReviewService.bump', () => ReviewService().incrementSessionCount());
  }());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
        ChangeNotifierProvider.value(value: IapService()),
        ChangeNotifierProvider.value(value: ThemeService()),
        ChangeNotifierProvider.value(value: PowerUpService()),
        ChangeNotifierProvider.value(value: WarehouseEconomyService()),
        ChangeNotifierProvider.value(value: BusinessTierService()),
        ChangeNotifierProvider.value(value: ContractService()),
        ChangeNotifierProvider.value(value: IncomeMultiplierService()),
        ChangeNotifierProvider.value(value: MachineryService()),
        ChangeNotifierProvider.value(value: CosmeticService()),
      ],
      child: const WarehouseSortApp(),
    ),
  );
}
