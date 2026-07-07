import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// A single ranked row in [TaqaLeaderboardCard]'s preview list.
class TaqaLeaderboardEntry {
  const TaqaLeaderboardEntry({required this.rank, required this.name});

  final int rank;
  final String name;
}

/// The group page's lime leaderboard preview card: title, current metric,
/// and a stacked list of the top-ranked names. Tapping opens the full
/// leaderboard.
class TaqaLeaderboardCard extends StatelessWidget {
  const TaqaLeaderboardCard({
    super.key,
    required this.metricLabel,
    required this.topEntries,
    this.title = 'Leaderboard',
    this.onTap,
  });

  final String title;
  final String metricLabel;

  /// Up to 3 ranked entries, rendered stacked one per line: the rank
  /// number aligned with the title, the name kept at its original offset.
  final List<TaqaLeaderboardEntry> topEntries;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.communityLeaderboardCardWidth,
        );
        final cardHeight = TaqaUiStyles.communityLeaderboardCardHeight;
        final layoutScale = math.min(
          1.0,
          cardWidth / TaqaUiStyles.communityLeaderboardCardWidth,
        );

        final contentLeft = TaqaUiScale.w(14) * layoutScale;
        final contentWidth = cardWidth - (contentLeft * 2);
        final titleTop = TaqaUiScale.h(17) * layoutScale;
        final listTop = TaqaUiScale.h(38) * layoutScale;
        final rankWidth = TaqaUiScale.w(28) * layoutScale;
        final nameLeft = TaqaUiScale.w(62) * layoutScale;
        final nameWidth = math.min(
          TaqaUiScale.w(281) * layoutScale,
          cardWidth - nameLeft - contentLeft,
        );
        // Row offsets relative to the list container, matching the design
        // spec: metric header at 0, then ranked names at 24/36/48.
        final entryTops = [
          TaqaUiScale.h(24) * layoutScale,
          TaqaUiScale.h(36) * layoutScale,
          TaqaUiScale.h(48) * layoutScale,
        ];

        return SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Material(
            color: TaqaUiColors.lime,
            borderRadius: TaqaUiStyles.communityGroupCardRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: TaqaUiStyles.communityGroupCardRadius,
              child: Stack(
                children: [
                  Positioned(
                    left: contentLeft,
                    top: titleTop,
                    width: contentWidth,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityGroupCardName,
                    ),
                  ),
                  Positioned(
                    left: contentLeft,
                    top: listTop,
                    width: contentWidth,
                    child: Text(
                      metricLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityGroupCardDescription,
                    ),
                  ),
                  for (var i = 0; i < math.min(topEntries.length, 3); i++) ...[
                    Positioned(
                      left: contentLeft,
                      top: listTop + entryTops[i],
                      width: rankWidth,
                      child: Text(
                        '#${topEntries[i].rank}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaqaUiStyles.communityLeaderboardNames,
                      ),
                    ),
                    Positioned(
                      left: nameLeft,
                      top: listTop + entryTops[i],
                      width: nameWidth,
                      child: Text(
                        topEntries[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaqaUiStyles.communityLeaderboardNames,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
