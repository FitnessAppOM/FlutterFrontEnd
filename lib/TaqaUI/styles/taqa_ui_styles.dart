import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

class TaqaUiStyles {
  TaqaUiStyles._();

  static const double mainCardWidth = 357;
  static const double mainCardHeight = 232;
  static const double avatarSize = 35;
  static const double weekdayDotSize = 35;
  static const double actionButtonWidth = 157;
  static const double actionButtonHeight = 45;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(28));
  static const BorderRadius circleRadius = BorderRadius.all(
    Radius.circular(999),
  );

  static const TextStyle userName = TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    color: TaqaUiColors.charcoal,
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.05,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    color: TaqaUiColors.charcoal,
    fontSize: 15,
    fontWeight: FontWeight.w300,
    height: 1.25,
  );

  static const TextStyle weekdayLabel = TextStyle(
    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
    color: TaqaUiColors.charcoal,
    fontSize: 8,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );

  static const TextStyle actionButton = TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    color: TaqaUiColors.charcoal,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );
}
