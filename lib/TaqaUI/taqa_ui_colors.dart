import 'package:flutter/material.dart';

/// Raw, mode-independent colors from the Taqa design system.
///
/// Widgets should use [BuildContextTaqaUiColors.taqaColors] for structural
/// colors (backgrounds, surfaces, text and borders). These constants are for
/// brand, feedback and data-visualization colors that do not change with the
/// selected appearance.
class TaqaUiColors {
  TaqaUiColors._();

  // Raw palette values from design.
  static const Color unnamedColor1c1d17 = Color(0xFF1C1D17);
  static const Color unnamedColorE3e3e3 = Color(0xFFE3E3E3);
  static const Color unnamedColorE4e93b = Color(0xFFE4E93B);
  static const Color unnamedColorE93b3b = Color(0xFFE93B3B);
  static const Color lime = unnamedColorE4e93b;
  static const Color recordRed = unnamedColorE93b3b;
  static const Color charcoal = unnamedColor1c1d17;
  static const Color graphite = Color(0xFF404040);
  static const Color lightGray = unnamedColorE3e3e3;
  static const Color white = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color accent = lime;

  // Weekday status colors
  static const Color weekdayPast = Color(0xFF908D8B);
  static const Color weekdayFuture = Color(0xFFE3E3E3);

  // Dashboard states
  static const Color dashboardTopCardPastDay = Color(0xFFC9C9CB);
}

/// Theme-aware semantic colors used by all Taqa UI components.
///
/// Both palettes live here so changing a color never requires editing feature
/// widgets. Add new semantic roles here rather than adding raw hex values to a
/// screen or component.
@immutable
class TaqaUiPalette extends ThemeExtension<TaqaUiPalette> {
  const TaqaUiPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceInverse,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnInverse,
    required this.border,
    required this.divider,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.scrim,
  });

  static const TaqaUiPalette light = TaqaUiPalette(
    brightness: Brightness.light,
    background: TaqaUiColors.lightGray,
    surface: TaqaUiColors.white,
    surfaceElevated: Color(0xFFF5F5F2),
    surfaceInverse: TaqaUiColors.charcoal,
    textPrimary: TaqaUiColors.charcoal,
    textSecondary: Color(0x991C1D17),
    textOnInverse: TaqaUiColors.white,
    border: Color(0x241C1D17),
    divider: Color(0x1F1C1D17),
    accent: TaqaUiColors.lime,
    onAccent: TaqaUiColors.charcoal,
    danger: TaqaUiColors.recordRed,
    success: TaqaUiColors.successGreen,
    scrim: Color(0x66000000),
  );

  static const TaqaUiPalette dark = TaqaUiPalette(
    brightness: Brightness.dark,
    background: TaqaUiColors.charcoal,
    surface: Color(0xFF2A2B26),
    surfaceElevated: TaqaUiColors.graphite,
    surfaceInverse: TaqaUiColors.white,
    textPrimary: TaqaUiColors.white,
    textSecondary: Color(0xB3FFFFFF),
    textOnInverse: TaqaUiColors.charcoal,
    border: Color(0x2EFFFFFF),
    divider: Color(0x24FFFFFF),
    accent: TaqaUiColors.lime,
    onAccent: TaqaUiColors.charcoal,
    danger: TaqaUiColors.recordRed,
    success: TaqaUiColors.successGreen,
    scrim: Color(0x99000000),
  );

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceInverse;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnInverse;
  final Color border;
  final Color divider;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color success;
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  @override
  TaqaUiPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceInverse,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnInverse,
    Color? border,
    Color? divider,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? success,
    Color? scrim,
  }) {
    return TaqaUiPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceInverse: surfaceInverse ?? this.surfaceInverse,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnInverse: textOnInverse ?? this.textOnInverse,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  TaqaUiPalette lerp(covariant TaqaUiPalette? other, double t) {
    if (other == null) return this;
    return TaqaUiPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnInverse: Color.lerp(textOnInverse, other.textOnInverse, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

extension BuildContextTaqaUiColors on BuildContext {
  /// The active semantic Taqa palette for this part of the widget tree.
  TaqaUiPalette get taqaColors {
    final theme = Theme.of(this);
    return theme.extension<TaqaUiPalette>() ??
        (theme.brightness == Brightness.dark
            ? TaqaUiPalette.dark
            : TaqaUiPalette.light);
  }
}
