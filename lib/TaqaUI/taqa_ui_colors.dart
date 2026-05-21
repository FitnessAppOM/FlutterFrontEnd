import 'package:flutter/material.dart';

/// Shared color tokens for the new Taqa UI direction.
class TaqaUiColors {
  TaqaUiColors._();

  // Raw palette values from design.
  static const Color unnamedColor1c1d17 = Color(0xFF1C1D17);
  static const Color unnamedColorE3e3e3 = Color(0xFFE3E3E3);
  static const Color unnamedColorE4e93b = Color(0xFFE4E93B);
  static const Color lime = unnamedColorE4e93b;
  static const Color charcoal = unnamedColor1c1d17;
  static const Color graphite = Color(0xFF404040);
  static const Color lightGray = unnamedColorE3e3e3;
  static const Color white = Color(0xFFFFFFFF);

  // Semantic aliases for fast UI wiring.
  static const Color accent = lime;
  static const Color background = charcoal;
  static const Color surface = graphite;
  static const Color border = lightGray;
  static const Color textPrimary = white;

  // Weekday status colors
  static const Color weekdayPast = Color(0xFF908D8B);
  static const Color weekdayFuture = Color(0xFFE3E3E3);

  // Dashboard states
  static const Color dashboardTopCardPastDay = Color(0xFFC9C9CB);
}
