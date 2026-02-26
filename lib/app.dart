import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/theme_service.dart';
import 'utils/constants.dart';

class StakdApp extends StatelessWidget {
  const StakdApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes to rebuild the app
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final theme = themeService.currentTheme;
        
        // Determine brightness based on background color luminance
        final isDark = theme.backgroundColor.computeLuminance() < 0.5;
        
        return MaterialApp(
          title: 'SortBloom',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: theme.backgroundColor,
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: theme.accentColor,
                    secondary: theme.accentColor,
                    surface: theme.surfaceColor,
                    onSurface: theme.textColor,
                  )
                : ColorScheme.light(
                    primary: theme.accentColor,
                    secondary: theme.accentColor,
                    surface: theme.surfaceColor,
                    onSurface: theme.textColor,
                  ),
            textTheme: TextTheme(
              displayLarge: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              displayMedium: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              titleLarge: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
              titleMedium: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.textColor,
              ),
              bodyLarge: TextStyle(fontSize: 16, color: theme.textColor),
              bodyMedium: TextStyle(fontSize: 14, color: theme.textMutedColor),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.textColor,
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
                foregroundColor: theme.textColor,
                side: BorderSide(color: theme.accentColor, width: 2),
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
            iconTheme: IconThemeData(color: theme.textColor, size: 24),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
