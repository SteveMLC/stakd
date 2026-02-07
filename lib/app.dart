import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';

class StakdApp extends StatelessWidget {
  const StakdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stakd',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GameColors.background,
        colorScheme: ColorScheme.dark(
          primary: GameColors.accent,
          secondary: GameColors.accent,
          surface: GameColors.surface,
          onSurface: GameColors.text,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: GameColors.text,
          ),
          displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: GameColors.text,
          ),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: GameColors.text,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: GameColors.text,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: GameColors.text),
          bodyMedium: TextStyle(fontSize: 14, color: GameColors.textMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: GameColors.accent,
            foregroundColor: GameColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GameSizes.borderRadius),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: GameColors.text,
            side: const BorderSide(color: GameColors.accent, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GameSizes.borderRadius),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: GameColors.text, size: 24),
      ),
      home: const HomeScreen(),
    );
  }
}
