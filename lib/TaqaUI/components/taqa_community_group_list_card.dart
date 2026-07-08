import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// Wide 357x110 result row used by the discover community list (e.g. gyms,
/// coaches, cities). Mirrors [TaqaCommunityGroupCard]'s content styling but
/// laid out for a full-width list rather than a horizontal carousel tile.
class TaqaCommunityGroupListCard extends StatelessWidget {
  const TaqaCommunityGroupListCard({
    super.key,
    required this.tag,
    required this.name,
    required this.description,
    required this.memberCount,
    this.trailing,
    this.onTap,
  });

  final String tag;
  final String name;
  final String description;
  final int memberCount;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth = TaqaUiStyles.communityGroupListCardWidth;
    final cardHeight = TaqaUiStyles.communityGroupListCardHeight;
    final contentLeft = TaqaUiScale.w(14);
    final contentWidth = cardWidth - (contentLeft * 2);
    final tagTop = TaqaUiScale.h(14);
    final nameTop = TaqaUiScale.h(43);
    // The design spec's 16px gap (59 - 43) is measured against the title's
    // nominal 15px box, but its 20/15 line-height renders taller than that,
    // which crowded the description right underneath it. Pad the gap out to
    // clear the title's actual line box, then keep the description->members
    // spacing from the original spec (24px).
    final descriptionTop = TaqaUiScale.h(66);
    final membersTop = TaqaUiScale.h(66 + 24);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.communityGroupCardRadius,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiStyles.communityGroupCardRadius,
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
                  style: TaqaUiStyles.communityGroupCardName,
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
                top: membersTop,
                width: contentWidth,
                child: Text(
                  '$memberCount members',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.communityGroupCardMembers,
                ),
              ),
              if (trailing != null)
                Positioned(
                  right: TaqaUiScale.w(14),
                  top: tagTop,
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
