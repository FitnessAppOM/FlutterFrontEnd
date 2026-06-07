import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';
import 'taqa_ui_scale.dart';

class TaqaUiStyles {
  TaqaUiStyles._();

  static double get mainCardWidth => TaqaUiScale.w(357);
  static double get mainCardHeight => TaqaUiScale.h(232);
  static double get carouselCardWidth => TaqaUiScale.w(357);
  static double get carouselCardHeight => TaqaUiScale.h(143);
  static double get dailyOutlookCardWidth => TaqaUiScale.w(357);
  static double get dailyOutlookCardHeight => TaqaUiScale.h(200);
  static double get scoreCardWidth => TaqaUiScale.w(357);
  static double get scoreCardHeight => TaqaUiScale.h(153);
  static double get avatarSize => TaqaUiScale.w(35);
  static BorderRadius get avatarRadius => TaqaUiScale.radius(31);
  static double get weekdayDotSize => TaqaUiScale.w(35);
  static double get weekdayTrackWidth => TaqaUiScale.w(330);
  static double get actionButtonWidth => TaqaUiScale.w(157);
  static double get actionButtonHeight => TaqaUiScale.h(45);
  static double get introDescriptionWidth => TaqaUiScale.w(329);
  static double get carouselContentWidth => TaqaUiScale.w(329);
  static double get dailyOutlookContentWidth => TaqaUiScale.w(329);
  static double get scoreCardTitleWidth => TaqaUiScale.w(130);
  static double get scoreCardMetaWidth => TaqaUiScale.w(78);
  static BorderRadius get actionButtonRadius => TaqaUiScale.radius(5);

  static BorderRadius get cardRadius => TaqaUiScale.radius(28);
  static BorderRadius get introCardRadius => TaqaUiScale.radius(15);
  static BorderRadius get carouselCardRadius => TaqaUiScale.radius(15);
  static BorderRadius get dailyOutlookCardRadius => TaqaUiScale.radius(15);
  static BorderRadius get scoreCardRadius => TaqaUiScale.radius(15);
  static BorderRadius get circleRadius => TaqaUiScale.radius(999);

  static TextStyle get userName => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    color: TaqaUiColors.charcoal,
    fontSize: TaqaUiScale.sp(25),
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static TextStyle get subtitle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    color: TaqaUiColors.charcoal,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w300,
    height: 18 / 15,
  );

  static TextStyle get weekdayLabel => TextStyle(
    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
    color: TaqaUiColors.charcoal,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );

  static TextStyle get actionButton => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    color: TaqaUiColors.charcoal,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static TextStyle get pageTitle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 25 / 15,
  );

  static TextStyle get carouselDate => TextStyle(
    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.white,
    letterSpacing: 0,
    height: 10 / 8,
  );

  static TextStyle get carouselTitle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.white,
    letterSpacing: 0,
    height: 25 / 15,
  );

  static TextStyle get carouselDescription => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.white,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get dailyOutlookTag => TextStyle(
    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 10 / 8,
  );

  static TextStyle get dailyOutlookTitle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 25 / 15,
  );

  static TextStyle get dailyOutlookDescription => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get dailyOutlookButton => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w600,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get scoreCardTitle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 25 / 15,
  );

  static TextStyle get scoreCardMeta => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 11 / 8,
  );

  static TextStyle get scoreCardValue => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(25),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 1,
  );

  static TextStyle get scoreCardTag => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 10 / 8,
  );
}
