import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// The main card on a group's own page: tag, name, description, and a
/// members/leaderboard stat row.
class TaqaCommunityGroupHeroCard extends StatelessWidget {
  const TaqaCommunityGroupHeroCard({
    super.key,
    required this.tag,
    required this.name,
    required this.description,
    required this.membersValue,
    required this.leaderboardValue,
    this.membersLabel = 'Members',
    this.leaderboardLabel = 'Leaderboard',
    this.onTap,
    this.onMembersTap,
    this.onLeaderboardTap,
    this.actionIcon,
    this.onActionTap,
  });

  final String tag;
  final String name;
  final String description;
  final String membersValue;
  final String leaderboardValue;
  final String membersLabel;
  final String leaderboardLabel;
  final VoidCallback? onTap;
  final VoidCallback? onMembersTap;
  final VoidCallback? onLeaderboardTap;

  /// A small logo-style icon button in the card's top-right corner (e.g.
  /// for leave/join group). Omitted when either field is null.
  final IconData? actionIcon;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.communityGroupHeroCardWidth,
        );
        final cardHeight = TaqaUiStyles.communityGroupHeroCardHeight;
        final layoutScale = math.min(
          1.0,
          cardWidth / TaqaUiStyles.communityGroupHeroCardWidth,
        );

        final contentLeft = TaqaUiScale.w(14) * layoutScale;
        final contentWidth = cardWidth - (contentLeft * 2);
        final tagTop = TaqaUiScale.h(17) * layoutScale;
        final nameTop = TaqaUiScale.h(40) * layoutScale;
        final descriptionTop = TaqaUiScale.h(65) * layoutScale;
        final boxesTop = TaqaUiScale.h(107) * layoutScale;
        final boxWidth = TaqaUiStyles.communityStatBoxWidth * layoutScale;
        final boxHeight = TaqaUiStyles.communityStatBoxHeight * layoutScale;
        final boxGap = TaqaUiScale.w(15) * layoutScale;
        final actionSize = TaqaUiScale.w(28) * layoutScale;
        final actionTop = TaqaUiScale.h(14) * layoutScale;
        final actionRight = TaqaUiScale.w(14) * layoutScale;

        return SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Material(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiStyles.communityGroupCardRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: TaqaUiStyles.communityGroupCardRadius,
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
                      style: TaqaUiStyles.communityGroupHeroName,
                    ),
                  ),
                  Positioned(
                    left: contentLeft,
                    top: descriptionTop,
                    width: contentWidth,
                    child: Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityGroupCardDescription,
                    ),
                  ),
                  Positioned(
                    left: contentLeft,
                    top: boxesTop,
                    child: Row(
                      children: [
                        _TaqaCommunityGroupStatBox(
                          width: boxWidth,
                          height: boxHeight,
                          layoutScale: layoutScale,
                          label: membersLabel,
                          value: membersValue,
                          isNumericValue: true,
                          onTap: onMembersTap,
                        ),
                        SizedBox(width: boxGap),
                        _TaqaCommunityGroupStatBox(
                          width: boxWidth,
                          height: boxHeight,
                          layoutScale: layoutScale,
                          label: leaderboardLabel,
                          value: leaderboardValue,
                          onTap: onLeaderboardTap,
                        ),
                      ],
                    ),
                  ),
                  if (actionIcon != null && onActionTap != null)
                    Positioned(
                      top: actionTop,
                      right: actionRight,
                      child: Material(
                        color: TaqaUiColors.lightGray,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onActionTap,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: actionSize,
                            height: actionSize,
                            child: Icon(
                              actionIcon,
                              size: actionSize * 0.55,
                              color: TaqaUiColors.charcoal,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TaqaCommunityGroupStatBox extends StatelessWidget {
  const _TaqaCommunityGroupStatBox({
    required this.width,
    required this.height,
    required this.layoutScale,
    required this.label,
    required this.value,
    this.isNumericValue = false,
    this.onTap,
  });

  final double width;
  final double height;
  final double layoutScale;
  final String label;
  final String value;

  /// True for the members count: a short number rendered big, centered,
  /// and uppercase. False (the default) renders text values like a
  /// leaderboard metric small, left-aligned, and lowercase so long words
  /// don't overflow the box.
  final bool isNumericValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contentLeft = TaqaUiScale.w(7) * layoutScale;
    final labelTop = TaqaUiScale.h(7) * layoutScale;

    final valueTop = TaqaUiScale.h(isNumericValue ? 40 : 47) * layoutScale;
    final valueLeft = isNumericValue
        ? TaqaUiScale.w(5) * layoutScale
        : contentLeft;
    final valueWidth = isNumericValue
        ? TaqaUiScale.w(14) * layoutScale
        : math.min(TaqaUiScale.w(111) * layoutScale, width - contentLeft * 2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.communityStatBoxRadius,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: TaqaUiColors.lightGray,
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
                left: valueLeft,
                top: valueTop,
                width: valueWidth,
                child: Text(
                  isNumericValue ? value.toUpperCase() : value.toLowerCase(),
                  textAlign: isNumericValue ? TextAlign.center : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isNumericValue
                      ? TaqaUiStyles.scoreCardValue
                      : TaqaUiStyles.communityGroupStatValueText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
