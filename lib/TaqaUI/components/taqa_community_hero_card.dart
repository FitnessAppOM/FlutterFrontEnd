import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityHeroCard extends StatelessWidget {
  const TaqaCommunityHeroCard({
    super.key,
    this.title = 'Community',
    required this.welcomeText,
    required this.badgeCount,
    required this.groupCount,
    required this.challengeCount,
    required this.reportCount,
    this.onBadgesTap,
    this.onGroupsTap,
    this.onChallengesTap,
    this.onReportsTap,
  });

  final String title;
  final String welcomeText;
  final int badgeCount;
  final int groupCount;
  final int challengeCount;
  final int reportCount;
  final VoidCallback? onBadgesTap;
  final VoidCallback? onGroupsTap;
  final VoidCallback? onChallengesTap;
  final VoidCallback? onReportsTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.communityHeroCardWidth,
        );
        final cardHeight = TaqaUiStyles.communityHeroCardHeight;
        final layoutScale = math.min(
          1.0,
          cardWidth / TaqaUiStyles.communityHeroCardWidth,
        );
        final leftInset = TaqaUiScale.w(15) * layoutScale;
        final titleTop = TaqaUiScale.h(15) * layoutScale;
        final titleHeight = TaqaUiScale.h(18) * layoutScale;
        final welcomeTop = TaqaUiScale.h(34) * layoutScale;
        final welcomeWidth = TaqaUiScale.w(328) * layoutScale;
        final welcomeHeight = TaqaUiScale.h(30) * layoutScale;
        final boxesTop = TaqaUiScale.h(94) * layoutScale;
        final boxesLeft = TaqaUiScale.w(14) * layoutScale;
        final boxWidth = TaqaUiStyles.communityStatBoxWidth * layoutScale;
        final boxHeight = TaqaUiStyles.communityStatBoxHeight * layoutScale;
        final boxGap = TaqaUiScale.w(15) * layoutScale;

        return SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Container(
            decoration: BoxDecoration(
              color: TaqaUiColors.white,
              borderRadius: TaqaUiStyles.communityHeroCardRadius,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: leftInset,
                  top: titleTop,
                  width: math.min(welcomeWidth, cardWidth - (leftInset * 2)),
                  height: titleHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityPageTitle,
                    ),
                  ),
                ),
                Positioned(
                  left: leftInset,
                  top: welcomeTop,
                  width: math.min(welcomeWidth, cardWidth - (leftInset * 2)),
                  height: welcomeHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      welcomeText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.userName,
                    ),
                  ),
                ),
                Positioned(
                  left: boxesLeft,
                  top: boxesTop,
                  child: _TaqaCommunityStatGrid(
                    boxWidth: boxWidth,
                    boxHeight: boxHeight,
                    boxGap: boxGap,
                    layoutScale: layoutScale,
                    badgeCount: badgeCount,
                    groupCount: groupCount,
                    challengeCount: challengeCount,
                    reportCount: reportCount,
                    onBadgesTap: onBadgesTap,
                    onGroupsTap: onGroupsTap,
                    onChallengesTap: onChallengesTap,
                    onReportsTap: onReportsTap,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TaqaCommunityStatGrid extends StatelessWidget {
  const _TaqaCommunityStatGrid({
    required this.boxWidth,
    required this.boxHeight,
    required this.boxGap,
    required this.layoutScale,
    required this.badgeCount,
    required this.groupCount,
    required this.challengeCount,
    required this.reportCount,
    this.onBadgesTap,
    this.onGroupsTap,
    this.onChallengesTap,
    this.onReportsTap,
  });

  final double boxWidth;
  final double boxHeight;
  final double boxGap;
  final double layoutScale;
  final int badgeCount;
  final int groupCount;
  final int challengeCount;
  final int reportCount;
  final VoidCallback? onBadgesTap;
  final VoidCallback? onGroupsTap;
  final VoidCallback? onChallengesTap;
  final VoidCallback? onReportsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TaqaCommunityStatBox(
              width: boxWidth,
              height: boxHeight,
              layoutScale: layoutScale,
              color: TaqaUiColors.lime,
              label: 'Badges',
              icon: Icons.workspace_premium_rounded,
              onTap: onBadgesTap,
            ),
            SizedBox(width: boxGap),
            _TaqaCommunityStatBox(
              width: boxWidth,
              height: boxHeight,
              layoutScale: layoutScale,
              color: TaqaUiColors.lightGray,
              label: 'Groups',
              value: groupCount,
              onTap: onGroupsTap,
            ),
          ],
        ),
        SizedBox(height: boxGap),
        Row(
          children: [
            _TaqaCommunityStatBox(
              width: boxWidth,
              height: boxHeight,
              layoutScale: layoutScale,
              color: TaqaUiColors.lightGray,
              label: 'Challenges',
              value: challengeCount,
              onTap: onChallengesTap,
            ),
            SizedBox(width: boxGap),
            _TaqaCommunityStatBox(
              width: boxWidth,
              height: boxHeight,
              layoutScale: layoutScale,
              color: TaqaUiColors.lightGray,
              label: 'Reports',
              value: reportCount,
              onTap: onReportsTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _TaqaCommunityStatBox extends StatelessWidget {
  const _TaqaCommunityStatBox({
    required this.width,
    required this.height,
    required this.layoutScale,
    required this.color,
    required this.label,
    this.value,
    this.icon,
    this.onTap,
  });

  final double width;
  final double height;
  final double layoutScale;
  final Color color;
  final String label;
  final int? value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contentLeft = TaqaUiScale.w(16) * layoutScale;
    final labelTop = TaqaUiScale.h(12) * layoutScale;
    final contentTop = TaqaUiScale.h(40) * layoutScale;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.communityStatBoxRadius,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: TaqaUiStyles.communityStatBoxRadius,
          ),
          child: Stack(
            children: [
              Positioned(
                left: contentLeft,
                top: labelTop,
                right: contentLeft,
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.dailyOutlookTag,
                ),
              ),
              Positioned(
                left: contentLeft,
                top: contentTop,
                child: icon != null
                    ? SizedBox(
                        width: TaqaUiStyles.communityStatIconWidth * layoutScale,
                        height: TaqaUiStyles.communityStatIconHeight * layoutScale,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Icon(icon, color: TaqaUiColors.charcoal),
                        ),
                      )
                    : Text(
                        '${value ?? 0}',
                        style: TaqaUiStyles.scoreCardValue,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
