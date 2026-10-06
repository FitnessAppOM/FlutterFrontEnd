import 'package:flutter/material.dart';

import '../TaqaUI/styles/taqa_ui_styles.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class AppColors {
  static const black = TaqaUiColors.charcoal;
  static const white = TaqaUiColors.white;
  static const appBackground = TaqaUiColors.lightGray;

  static const accent = TaqaUiColors.lime;

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

  static const body = TextStyle(color: AppColors.white, fontSize: 15);

  static const small = TextStyle(color: AppColors.textDim, fontSize: 13);
}

ThemeData _buildTaqaTheme(TaqaUiPalette palette) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: palette.brightness,
    ),
  );
  final pageTitleStyle = TaqaUiStyles.pageTitle.copyWith(
    color: palette.textPrimary,
  );

  return base.copyWith(
    scaffoldBackgroundColor: palette.background,
    colorScheme: base.colorScheme.copyWith(
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      error: palette.danger,
    ),
    extensions: <ThemeExtension<dynamic>>[palette],
    canvasColor: palette.background,
    cardColor: palette.surface,
    dialogTheme: DialogThemeData(backgroundColor: palette.surface),
    dividerColor: palette.divider,
    iconTheme: IconThemeData(color: palette.textPrimary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      labelStyle: TextStyle(color: palette.textSecondary),
      hintStyle: TextStyle(color: palette.textSecondary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: pageTitleStyle,
      toolbarTextStyle: pageTitleStyle,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.surfaceElevated;
          }
          return palette.accent;
        }),
        foregroundColor: WidgetStateProperty.all(palette.onAccent),
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
        foregroundColor: palette.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData buildDarkTheme() => _buildTaqaTheme(TaqaUiPalette.dark);

ThemeData buildLightTheme() => _buildTaqaTheme(TaqaUiPalette.light);

class AppTheme {
  static ThemeData dark() => buildDarkTheme();
  static ThemeData light() => buildLightTheme();
}
