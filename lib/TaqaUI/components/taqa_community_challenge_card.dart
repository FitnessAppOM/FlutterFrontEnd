import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityChallengeCard extends StatelessWidget {
  const TaqaCommunityChallengeCard({
    super.key,
    required this.tag,
    required this.name,
    required this.progress,
    this.onTap,
  });

  final String tag;
  final String name;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final cardWidth = TaqaUiStyles.communityChallengeCardWidth;
    final cardHeight = TaqaUiStyles.communityChallengeCardHeight;
    final contentLeft = TaqaUiScale.w(14);
    final contentWidth = cardWidth - (contentLeft * 2);
    final tagTop = TaqaUiScale.h(12);
    final nameTop = TaqaUiScale.h(40);
    final barTop = TaqaUiScale.h(66);
    final barWidth = TaqaUiStyles.communityChallengeBarWidth;
    final barHeight = TaqaUiStyles.communityChallengeBarHeight;
    final percentageLeft = TaqaUiScale.w(279);
    final percentageTop = TaqaUiScale.h(58);
    final percentageWidth = TaqaUiScale.w(64);
    final percentageHeight = TaqaUiScale.h(30);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.communityHeroCardRadius,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiStyles.communityHeroCardRadius,
          ),
          child: Stack(
            children: [
              Positioned(
                left: contentLeft,
                top: tagTop,
                width: contentWidth,
                child: Text(
                  tag.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.dailyOutlookTag,
                ),
              ),
              Positioned(
                left: contentLeft,
                top: nameTop,
                width: contentWidth,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.communityChallengeName,
                ),
              ),
              Positioned(
                left: contentLeft,
                top: barTop,
                width: barWidth,
                height: barHeight,
                child: ClipRRect(
                  borderRadius: TaqaUiStyles.communityChallengeBarRadius,
                  child: Stack(
                    children: [
                      Container(color: TaqaUiColors.lightGray),
                      FractionallySizedBox(
                        widthFactor: math.max(0.0, clampedProgress),
                        heightFactor: 1,
                        child: Container(color: TaqaUiColors.lime),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: percentageLeft,
                top: percentageTop,
                width: percentageWidth,
                height: percentageHeight,
                child: Text(
                  '${(clampedProgress * 100).round()}%',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
