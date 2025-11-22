import 'package:flutter/material.dart';

class AppColors {
  static const black = Colors.black;
  static const white = Colors.white;
  static const accent = Colors.blue;
  static const textDim = Colors.white70;
  static const chipGrey = Color(0xFFE9E9E9);
  static const surfaceDark = Color(0xFF1E1E1E); // cards/buttons on dark
  static const dividerDark = Color(0xFF2A2A2A);
}

class AppRadii {
  static const pill = 14.0;
  static const tile = 12.0;
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark();

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.black,

    // Inputs
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white70),
      hintStyle: TextStyle(color: Colors.white38),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.dividerDark),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 1.4),
      ),
    ),

    dividerColor: AppColors.dividerDark,

    // Primary button (used by PrimaryWhiteButton wrapper)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF3A3A3A); // greyed when disabled
          }
          return AppColors.white;
        }),
        foregroundColor: WidgetStateProperty.all(Colors.black),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData buildLightTheme() {
  final base = ThemeData.light();

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.white,
  );
}

class AppTheme {
  static ThemeData dark() => buildDarkTheme();
  static ThemeData light() => buildLightTheme();
}
