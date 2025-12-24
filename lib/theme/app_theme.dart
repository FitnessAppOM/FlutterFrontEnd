import 'package:flutter/material.dart';

class AppColors {
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  static const accent = Colors.blue;

  // Greys
  static const greyDark = Color(0xFF2D2D2D);
  static const greyMedium = Color(0xFF3A3A3A);
  static const greyLight = Color(0xFFBEBEBE);

  static const textDim = Colors.white70;
  static const iconDim = Colors.white54;

  // UI background surfaces
  static const surfaceDark = Color(0xFF1E1E1E);
  static const cardDark = Color(0xFF121212);
  static const dividerDark = Color(0xFF2A2A2A);

  // Feedback colors
  static const errorRed = Color(0xFFE74C3C);
  static const successGreen = Color(0xFF28A745);

  static const chipGrey = Color(0xFFE9E9E9);
}



class AppRadii {
  static const pill = 14.0;
  static const tile = 12.0;
  static const circle = 9999.0;
}

class AppTextStyles {
  static const title = TextStyle(
    color: AppColors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const subtitle = TextStyle(
    color: AppColors.white,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const body = TextStyle(
    color: AppColors.white,
    fontSize: 15,
  );

  static const small = TextStyle(
    color: AppColors.textDim,
    fontSize: 13,
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark();

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.black,

    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.black,
    ),

    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: AppColors.textDim),
      hintStyle: TextStyle(color: Colors.white38),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.dividerDark),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 1.4),
      ),
    ),

    dividerColor: AppColors.dividerDark,

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.greyMedium;
          }
          return AppColors.white;
        }),
        foregroundColor: WidgetStateProperty.all(AppColors.black),
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
    scaffoldBackgroundColor: AppColors.white,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
    ),
  );
}

class AppTheme {
  static ThemeData dark() => buildDarkTheme();
  static ThemeData light() => buildLightTheme();
}