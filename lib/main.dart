import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/game_state.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';
import 'services/ad_service.dart';
import 'services/review_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  // Initialize services
  await StorageService().init();
  await AudioService().init();
  await AdService().init();
  
  // Initialize review service and increment session count
  final prefs = await SharedPreferences.getInstance();
  await ReviewService().init(prefs);
  await ReviewService().incrementSessionCount();
  
  // Load saved settings
  final audioService = AudioService();
  audioService.setSoundEnabled(StorageService().getSoundEnabled());
  audioService.setMusicEnabled(StorageService().getMusicEnabled());
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
      ],
      child: const StakdApp(),
    ),
  );
}
