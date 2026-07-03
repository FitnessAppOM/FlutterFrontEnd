import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityGroupCard extends StatelessWidget {
  const TaqaCommunityGroupCard({
    super.key,
    required this.tag,
    required this.name,
    required this.description,
    required this.memberCount,
    this.onTap,
  });

  final String tag;
  final String name;
  final String description;
  final int memberCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth = TaqaUiStyles.communityGroupCardWidth;
    final cardHeight = TaqaUiStyles.communityGroupCardHeight;
    final contentLeft = TaqaUiScale.w(14);
    final contentWidth = cardWidth - (contentLeft * 2);
    final tagTop = TaqaUiScale.h(17);
    final nameTop = TaqaUiScale.h(92);
    final descriptionTop = TaqaUiScale.h(117);
    final membersTop = TaqaUiScale.h(153);

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
            ],
          ),
        ),
      ),
    );
  }
}
