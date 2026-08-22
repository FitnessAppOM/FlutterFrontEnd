import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../Typography/taqa_ui_typography.dart';
import '../../localization/app_localizations.dart';

import 'taqa_adaptive_name_text.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityHeroCard extends StatelessWidget {
  const TaqaCommunityHeroCard({
    super.key,
    this.title,
    required this.welcomeText,
    this.greetingText,
    this.userNameText,
    required this.badgeCount,
    required this.groupCount,
    required this.challengeCount,
    required this.reportCount,
    required this.showReports,
    this.onBadgesTap,
    this.onGroupsTap,
    this.onChallengesTap,
    this.onReportsTap,
  });

  final String? title;
  final String welcomeText;
  final String? greetingText;
  final String? userNameText;
  final int badgeCount;
  final int groupCount;
  final int challengeCount;
  final int reportCount;
  final bool showReports;
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
        final hasTitle = title != null && title!.isNotEmpty;
        final leftInset = TaqaUiScale.w(15) * layoutScale;
        final titleTop = TaqaUiScale.h(15) * layoutScale;
        final titleHeight = TaqaUiScale.h(18) * layoutScale;
        final welcomeTop = TaqaUiScale.h(hasTitle ? 34 : 15) * layoutScale;
        final welcomeWidth = TaqaUiScale.w(328) * layoutScale;
        // The greeting and scrolling full name always share one line.
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
                if (hasTitle)
                  Positioned(
                    left: leftInset,
                    top: titleTop,
                    width: math.min(welcomeWidth, cardWidth - (leftInset * 2)),
                    height: titleHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title!,
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
                    child: TaqaAdaptiveNameText(
                      welcomeText: welcomeText,
                      greetingText: greetingText,
                      userNameText: userNameText,
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
                    showReports: showReports,
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
    required this.showReports,
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
  final bool showReports;
  final VoidCallback? onBadgesTap;
  final VoidCallback? onGroupsTap;
  final VoidCallback? onChallengesTap;
  final VoidCallback? onReportsTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
              label: t.translate('community_badges'),
              badgeCount: badgeCount,
              onTap: onBadgesTap,
            ),
            SizedBox(width: boxGap),
            _TaqaCommunityStatBox(
              width: boxWidth,
              height: boxHeight,
              layoutScale: layoutScale,
              color: TaqaUiColors.lightGray,
              label: t.translate('community_groups'),
              value: groupCount,
              onTap: onGroupsTap,
            ),
          ],
        ),
        SizedBox(height: boxGap),
        Row(
          children: [
            _TaqaCommunityStatBox(
              width: showReports ? boxWidth : (boxWidth * 2) + boxGap,
              height: boxHeight,
              layoutScale: layoutScale,
              color: TaqaUiColors.lightGray,
              label: t.translate('community_challenges'),
              value: challengeCount,
              onTap: onChallengesTap,
            ),
            if (showReports) ...[
              SizedBox(width: boxGap),
              _TaqaCommunityStatBox(
                width: boxWidth,
                height: boxHeight,
                layoutScale: layoutScale,
                color: TaqaUiColors.lightGray,
                label: t.translate('community_reports'),
                value: reportCount,
                onTap: onReportsTap,
              ),
            ],
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
    this.badgeCount,
    this.onTap,
  });

  final double width;
  final double height;
  final double layoutScale;
  final Color color;
  final String label;
  final int? value;
  final int? badgeCount;
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
                  taqaUppercase(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.dailyOutlookTag,
                ),
              ),
              Positioned(
                left: contentLeft,
                top: contentTop,
                child: badgeCount != null
                    ? _TaqaBadgeChipStack(
                        count: badgeCount!,
                        layoutScale: layoutScale,
                      )
                    : Text('${value ?? 0}', style: TaqaUiStyles.scoreCardValue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlapping stack of badge chips: up to 3 shown front-to-back, followed by
/// a "+N" chip when there are more.
class _TaqaBadgeChipStack extends StatelessWidget {
  const _TaqaBadgeChipStack({required this.count, required this.layoutScale});

  final int count;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    final chipSize = TaqaUiStyles.communityBadgeChipSize * layoutScale;
    final overlap = TaqaUiStyles.communityBadgeChipOverlap * layoutScale;

    if (count <= 0) {
      return SizedBox(
        width: chipSize,
        height: chipSize,
        child: _badgeChip(chipSize, layoutScale, filled: false),
      );
    }

    final visible = math.min(count, 3);
    final overflow = count - visible;
    final hasOverflow = overflow > 0;
    final slots = visible + (hasOverflow ? 1 : 0);
    final totalWidth = chipSize + (slots - 1) * overlap;

    final children = <Widget>[];
    if (hasOverflow) {
      for (var i = 0; i < visible; i++) {
        children.add(
          Positioned(
            left: overlap * i,
            child: _badgeChip(chipSize, layoutScale),
          ),
        );
      }
      children.add(
        Positioned(
          left: overlap * visible,
          child: _overflowChip(chipSize, overflow),
        ),
      );
    } else {
      for (var i = 0; i < visible; i++) {
        children.add(
          Positioned(
            left: overlap * i,
            child: _badgeChip(chipSize, layoutScale),
          ),
        );
      }
    }

    return SizedBox(
      width: totalWidth,
      height: chipSize,
      child: Stack(children: children),
    );
  }

  Widget _badgeChip(double size, double layoutScale, {bool filled = true}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? TaqaUiColors.white : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: filled ? 0.12 : 0.35),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(
            TaqaUiStyles.communityBadgeChipIconSize * layoutScale * 0.32,
          ),
          child: Icon(
            filled
                ? Icons.workspace_premium_rounded
                : Icons.workspace_premium_outlined,
            color: TaqaUiColors.charcoal.withValues(alpha: filled ? 1 : 0.35),
          ),
        ),
      ),
    );
  }

  Widget _overflowChip(double size, int overflow) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: TaqaUiColors.charcoal,
        shape: BoxShape.circle,
      ),
      child: Text(
        '+$overflow',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TaqaUiStyles.communityBadgeStackOverflow,
      ),
    );
  }
}
