import 'package:flutter/material.dart';

/// Shared color tokens for the new Taqa UI direction.
class TaqaUiColors {
  TaqaUiColors._();

  // Raw palette values from design.
  static const Color lime = Color(0xFFE4E93B);
  static const Color charcoal = Color(0xFF1C1D17);
  static const Color graphite = Color(0xFF404040);
  static const Color lightGray = Color(0xFFE3E3E3);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic aliases for fast UI wiring.
  static const Color accent = lime;
  static const Color background = charcoal;
  static const Color surface = graphite;
  static const Color border = lightGray;
  static const Color textPrimary = white;

  // Weekday status colors
  static const Color weekdayPast = graphite;
  static const Color weekdayFuture = Color(0xFFC9C9CB);
}
