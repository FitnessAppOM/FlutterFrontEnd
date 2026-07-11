import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';
import 'taqa_score_widget.dart' show TaqaOpenArcPainter;

/// The exact lime-card / open-arc layout used by [TaqaScoreWidget] ("Taqa
/// Fitness Score"), generalized so any score-like metric (Whoop recovery,
/// strain, ...) can use the identical design instead of a one-off look.
class TaqaScoreCard extends StatelessWidget {
  const TaqaScoreCard({
    super.key,
    required this.title,
    required this.valueText,
    required this.progress,
    required this.loading,
    this.metaText = '',
    this.tags = const [],
    this.emptyMessage = 'No data yet',
    this.onTap,
  });

  final String title;
  final String valueText;
  final double progress;
  final bool loading;

  /// Shown under the title (e.g. "date\nsource").
  final String metaText;
  final List<String> tags;
  final String emptyMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = TaqaUiStyles.scoreCardWidth;
        final targetHeight = TaqaUiStyles.scoreCardHeight;
        final cardWidth = math.min(constraints.maxWidth, targetWidth);
        final layoutScale = cardWidth <= 0
            ? 1.0
            : math.min(1.0, cardWidth / targetWidth);
        final cardHeight = targetHeight * layoutScale;
        final cardRadius = TaqaUiScale.r(15) * layoutScale;
        final arcLeft = TaqaUiScale.w(16) * layoutScale;
        final arcTop = TaqaUiScale.h(13) * layoutScale;
        final arcSize = TaqaUiScale.w(141) * layoutScale;
        final arcVisibleHeight = TaqaUiScale.h(124) * layoutScale;
        final titleLeft = TaqaUiScale.w(186) * layoutScale;
        final titleTop = TaqaUiScale.h(20) * layoutScale;
        final contentRightInset = TaqaUiScale.w(16) * layoutScale;
        final titleWidth = math.max(
          0.0,
          cardWidth - titleLeft - contentRightInset,
        );
        final titleHeight = TaqaUiScale.h(32) * layoutScale;
        final descriptionTop = TaqaUiScale.h(49) * layoutScale;
        final descriptionWidth = math.max(
          0.0,
          cardWidth - titleLeft - contentRightInset,
        );
        final descriptionHeight = TaqaUiScale.h(22) * layoutScale;
        final tagsTop = TaqaUiScale.h(83) * layoutScale;
        final tagsWidth = math.max(
          0.0,
          cardWidth - titleLeft - contentRightInset,
        );
        final tagsHeight = math.max(
          0.0,
          cardHeight - tagsTop - (TaqaUiScale.h(12) * layoutScale),
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(cardRadius),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(cardRadius),
                child: Ink(
                  decoration: BoxDecoration(
                    color: TaqaUiColors.lime,
                    borderRadius: BorderRadius.circular(cardRadius),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: arcLeft,
                        top: arcTop,
                        width: arcSize,
                        height: arcVisibleHeight,
                        child: _ScoreCardArc(
                          progress: progress,
                          valueText: valueText,
                          loading: loading,
                          layoutScale: layoutScale,
                        ),
                      ),
                      Positioned(
                        left: titleLeft,
                        top: titleTop,
                        width: titleWidth,
                        height: titleHeight,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TaqaUiStyles.scoreCardTitle,
                        ),
                      ),
                      Positioned(
                        left: titleLeft,
                        top: descriptionTop,
                        width: descriptionWidth,
                        height: descriptionHeight,
                        child: Text(
                          metaText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TaqaUiStyles.scoreCardMeta,
                        ),
                      ),
                      Positioned(
                        left: titleLeft,
                        top: tagsTop,
                        width: tagsWidth,
                        height: tagsHeight,
                        child: _ScoreCardTags(
                          tags: tags,
                          emptyMessage: emptyMessage,
                          layoutScale: layoutScale,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreCardArc extends StatelessWidget {
  const _ScoreCardArc({
    required this.progress,
    required this.valueText,
    required this.loading,
    required this.layoutScale,
  });

  final double progress;
  final String valueText;
  final bool loading;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    final arcSize = TaqaUiScale.w(141) * layoutScale;
    final visibleHeight = TaqaUiScale.h(124) * layoutScale;
    final indicatorSize = TaqaUiScale.w(18) * layoutScale;

    return ClipRect(
      child: OverflowBox(
        maxWidth: arcSize,
        maxHeight: arcSize,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: arcSize,
          height: arcSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(arcSize),
                painter: TaqaOpenArcPainter(progress: progress),
              ),
              Transform.translate(
                offset: Offset(0, -((arcSize - visibleHeight) / 2)),
                child: loading
                    ? SizedBox(
                        width: indicatorSize,
                        height: indicatorSize,
                        child: CircularProgressIndicator(
                          strokeWidth: math.max(1.5, 2 * layoutScale),
                          color: TaqaUiColors.charcoal,
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: TaqaUiScale.w(14) * layoutScale,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            valueText,
                            textAlign: TextAlign.center,
                            style: TaqaUiStyles.scoreCardValue,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCardTags extends StatelessWidget {
  const _ScoreCardTags({
    required this.tags,
    required this.emptyMessage,
    required this.layoutScale,
  });

  final List<String> tags;
  final String emptyMessage;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          emptyMessage,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TaqaUiStyles.scoreCardMeta,
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: TaqaUiScale.w(6) * layoutScale,
        runSpacing: TaqaUiScale.h(6) * layoutScale,
        children: tags
            .map((tag) => _ScoreCardTag(text: tag, layoutScale: layoutScale))
            .toList(growable: false),
      ),
    );
  }
}

class _ScoreCardTag extends StatelessWidget {
  const _ScoreCardTag({required this.text, required this.layoutScale});

  final String text;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: TaqaUiScale.w(8) * layoutScale,
        vertical: TaqaUiScale.h(4) * layoutScale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TaqaUiScale.r(10) * layoutScale),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.72),
          width: math.max(0.8, layoutScale),
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TaqaUiStyles.scoreCardTag.copyWith(
          fontSize: (TaqaUiStyles.scoreCardTag.fontSize ?? 8) * layoutScale,
        ),
      ),
    );
  }
}
