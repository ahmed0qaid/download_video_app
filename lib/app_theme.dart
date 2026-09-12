import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF0F766E);
  static const tealDark = Color(0xFF45A89E);
  static const tealTint = Color(0xFFDCEDEA);
  static const canvas = Color(0xFFF6F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const charcoal = Color(0xFF181B1F);
  static const graphite = Color(0xFF4F565E);
  static const steel = Color(0xFF7C858F);
  static const line = Color(0xFFE3E6E8);
  static const softFill = Color(0xFFECEFF1);
  static const nightCanvas = Color(0xFF111416);
  static const nightSurface = Color(0xFF191D20);
  static const nightElevated = Color(0xFF21262B);
  static const nightLine = Color(0xFF2A3035);
  static const cloud = Color(0xFFF2F4F5);
  static const mist = Color(0xFFAAB1B7);
  static const error = Color(0xFFB54747);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
      surface: AppColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: AppColors.teal,
        secondary: AppColors.teal,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: AppColors.line,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.charcoal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.tealTint,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.steel,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.tealDark,
      brightness: Brightness.dark,
      surface: AppColors.nightSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: AppColors.tealDark,
        secondary: AppColors.tealDark,
        surface: AppColors.nightSurface,
        error: const Color(0xFFE06C75),
      ),
      scaffoldBackgroundColor: AppColors.nightCanvas,
      dividerColor: AppColors.nightLine,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.nightCanvas,
        foregroundColor: AppColors.cloud,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.nightCanvas,
        indicatorColor: AppColors.nightElevated,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.tealDark
                : AppColors.mist,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.nightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.nightLine),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.nightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.nightLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.nightLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.tealDark),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final primary =
        brightness == Brightness.dark ? AppColors.cloud : AppColors.charcoal;
    final secondary =
        brightness == Brightness.dark ? AppColors.mist : AppColors.graphite;
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: primary),
      bodyMedium: TextStyle(fontSize: 13, height: 1.45, color: secondary),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
    );
  }
}
