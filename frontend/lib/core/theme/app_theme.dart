import 'package:flutter/material.dart';

/// GEM Aromatics brand colours extracted from the company logo.
/// Green  : leaf / "GEM" text   → #5CB83C
/// Blue   : hand / "AROMATICS"  → #2B6CB8
class GemColors {
  static const green = Color(0xFF5CB83C);
  static const greenDark = Color(0xFF3F8A27);
  static const greenLight = Color(0xFFE8F5E0);

  static const blue = Color(0xFF2B6CB8);
  static const blueDark = Color(0xFF1A4A8A);
  static const blueLight = Color(0xFFE3EEF9);

  /// Sidebar / app-bar background
  static const darkSurface = Color(0xFF1A2B1A);

  /// Sidebar active-item highlight
  static const activeItem = Color(0xFF5CB83C);
}

class AppTheme {
  static ThemeData get lightTheme {
    final cs = ColorScheme.fromSeed(
      seedColor: GemColors.green,
      primary: GemColors.green,
      onPrimary: Colors.white,
      secondary: GemColors.blue,
      onSecondary: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: GemColors.darkSurface,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GemColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GemColors.green,
          side: const BorderSide(color: GemColors.green),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: GemColors.green, width: 1.5),
        ),
        floatingLabelStyle: const TextStyle(color: GemColors.green),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? GemColors.green
              : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? GemColors.green
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? GemColors.green.withOpacity(0.4)
              : null,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GemColors.green,
        brightness: Brightness.dark,
      ),
    );
  }
}
