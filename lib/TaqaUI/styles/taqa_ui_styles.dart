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
  static double get streakTagWidth => TaqaUiScale.w(48);
  static double get streakTagHeight => TaqaUiScale.h(20);
  static double get recordDotSize => TaqaUiScale.w(6);
  static double get communityHeroCardWidth => TaqaUiScale.w(357);
  static double get communityHeroCardHeight => TaqaUiScale.h(274);
  static double get communityStatBoxWidth => TaqaUiScale.w(157);
  static double get communityStatBoxHeight => TaqaUiScale.h(75);
  static double get communityBadgeChipSize => TaqaUiScale.w(21);
  static double get communityBadgeChipOverlap => TaqaUiScale.w(11);
  static double get communityBadgeChipIconSize => TaqaUiScale.w(12);
  static double get communityActionButtonWidth => TaqaUiScale.w(109);
  static double get communityActionRowWidth => TaqaUiScale.w(357);
  static double get communitySectionTagWidth => TaqaUiScale.w(58);
  static double get communityGroupCardWidth => TaqaUiScale.w(171);
  static double get communityGroupCardHeight => TaqaUiScale.h(171);
  static double get communityGroupListCardWidth => TaqaUiScale.w(357);
  static double get communityGroupListCardHeight => TaqaUiScale.h(110);
  static double get communityGroupHeroCardWidth => TaqaUiScale.w(357);
  static double get communityGroupHeroCardHeight => TaqaUiScale.h(197);
  static double get communityMuteCardWidth => TaqaUiScale.w(357);
  static double get communityMuteCardHeight => TaqaUiScale.h(65);
  static double get communityLeaderboardCardWidth => TaqaUiScale.w(357);
  static double get communityLeaderboardCardHeight => TaqaUiScale.h(113);
  static double get communityChallengeCardWidth => TaqaUiScale.w(357);
  static double get communityChallengeCardHeight => TaqaUiScale.h(98);
  static double get communityChallengeBarWidth => TaqaUiScale.w(250);
  static double get communityChallengeBarHeight => TaqaUiScale.h(17);
  static BorderRadius get actionButtonRadius => TaqaUiScale.radius(5);
  static BorderRadius get streakTagRadius => TaqaUiScale.radius(5);
  static BorderRadius get communityHeroCardRadius => TaqaUiScale.radius(15);
  static BorderRadius get communityStatBoxRadius => TaqaUiScale.radius(5);
  static BorderRadius get communityGroupCardRadius => TaqaUiScale.radius(5);
  static BorderRadius get communityChallengeBarRadius => TaqaUiScale.radius(9);

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

  static TextStyle get streakTag => TextStyle(
    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 10 / 8,
  );

  static TextStyle get scoreCardTag => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 10 / 8,
  );

  static TextStyle get communityActionButtonLabel => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w600,
    color: TaqaUiColors.white,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get communityFilterChipLabel => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w600,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get communityGroupCardName => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 20 / 15,
  );

  static TextStyle get communityGroupCardDescription => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get communityLeaderboardNames => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get communityGroupCardMembers => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w300,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 12 / 10,
  );

  static TextStyle get communityBadgeStackOverflow => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(9),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.white,
    letterSpacing: 0,
    height: 1,
  );

  static TextStyle get communityGroupHeroName => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(25),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 20 / 25,
  );

  static TextStyle get communityGroupStatValueText => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 25 / 15,
  );

  static TextStyle get communityChallengeName => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 25 / 15,
  );

  static TextStyle get communityPageTitle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(15),
    fontWeight: FontWeight.w400,
    color: TaqaUiColors.charcoal,
    letterSpacing: 0,
    height: 18 / 15,
  );
}
