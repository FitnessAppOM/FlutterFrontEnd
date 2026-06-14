import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/scores/taqa_score_api.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaScoreWidget extends StatelessWidget {
  const TaqaScoreWidget({
    super.key,
    required this.score,
    required this.loading,
    required this.onTap,
    this.provider,
    this.scoreDayLabel,
    this.emptyMessage = "No score data yet",
  });

  final TaqaDailyScore? score;
  final bool loading;
  final VoidCallback? onTap;
  final String? provider;
  final String? scoreDayLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final localizedTitle = AppLocalizations.of(
      context,
    ).translate('taqa_label_taqa_value');
    final taqaTitle = localizedTitle == 'TAQA Fitness Score'
        ? 'Taqa Fitness Score'
        : localizedTitle;
    final taqaValue = score?.taqaValueScore ?? 0;
    final displayValue = taqaValue.round();
    final progress = (taqaValue / 100).clamp(0.0, 1.0);
    final dateLabel = (scoreDayLabel == null || scoreDayLabel!.trim().isEmpty)
        ? '--.--'
        : scoreDayLabel!.replaceAll('/', '.');
    final displayProvider = score?.scoringPath == 'wearable'
        ? (provider ?? score?.provider)
        : null;
    final providerLabel = _scoreSourceLabel(score, displayProvider);
    final tags = _buildTags(score, displayProvider);

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
                        child: _ScoreArc(
                          progress: progress,
                          valueText: '$displayValue',
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
                          taqaTitle,
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
                          '$dateLabel\n$providerLabel',
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
                        child: _ScoreTags(
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

  String _providerLabel(String providerValue) {
    switch (providerValue) {
      case 'fitbit':
        return 'Fitbit';
      case 'whoop':
        return 'WHOOP';
      case 'google_fit':
        return 'Google Fit';
      case 'samsung':
        return 'Samsung Health';
      case 'healthkit':
        return 'Apple / Google';
      default:
        return providerValue;
    }
  }

  String _scoreSourceLabel(TaqaDailyScore? value, String? displayProvider) {
    if (displayProvider != null && displayProvider.trim().isNotEmpty) {
      return _providerLabel(displayProvider);
    }
    final scoringPath = value?.scoringPath;
    if (scoringPath == null || scoringPath.trim().isEmpty) return '--';
    switch (scoringPath) {
      case 'wearable':
        return 'Smart Watch';
      case 'proms':
        return 'Screening';
      default:
        return _humanizeLabel(scoringPath);
    }
  }

  List<_ScoreChipData> _buildTags(
    TaqaDailyScore? value,
    String? displayProvider,
  ) {
    if (value == null) return const [];
    final out = <_ScoreChipData>[];

    final sourceLabel = _chipSourceLabel(value, displayProvider);
    if (sourceLabel != null) {
      out.add(_ScoreChipData(sourceLabel));
    }

    void addIf(String label, double? score) {
      if (score == null) return;
      out.add(_ScoreChipData('${score.round()} $label'));
    }

    addIf('Sleep', value.sleep.score);
    addIf('Recovery', value.recovery.score);
    addIf('Stress', value.stress.score);
    addIf('Load', value.trainingLoad.score);
    addIf('Nutrition', value.nutrition.score);
    return out.take(4).toList(growable: false);
  }

  String? _chipSourceLabel(TaqaDailyScore value, String? displayProvider) {
    if (displayProvider != null && displayProvider.trim().isNotEmpty) {
      return _providerLabel(displayProvider).toUpperCase();
    }
    final scoringPath = value.scoringPath;
    if (scoringPath == null || scoringPath.trim().isEmpty) return null;
    switch (scoringPath) {
      case 'proms':
        return 'SCREENING';
      case 'wearable':
        return 'SMART WATCH';
      default:
        return _humanizeLabel(scoringPath).toUpperCase();
    }
  }

  String _humanizeLabel(String raw) {
    return raw
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }
}

class _ScoreArc extends StatelessWidget {
  const _ScoreArc({
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

class TaqaOpenArcPainter extends CustomPainter {
  const TaqaOpenArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.098;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = TaqaUiColors.charcoal.withValues(alpha: 0.14);

    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = TaqaUiColors.charcoal.withValues(alpha: 0.3);

    const start = 3 * math.pi / 4;
    const sweep = 3 * math.pi / 2;

    canvas.drawArc(rect, start, sweep, false, base);
    if (progress > 0) {
      canvas.drawArc(rect, start, sweep * progress, false, value);
    }
  }

  @override
  bool shouldRepaint(covariant TaqaOpenArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ScoreChipData {
  const _ScoreChipData(this.text);

  final String text;
}

class _ScoreTags extends StatelessWidget {
  const _ScoreTags({
    required this.tags,
    required this.emptyMessage,
    required this.layoutScale,
  });

  final List<_ScoreChipData> tags;
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
            .map((tag) {
              return _ScoreChip(tag: tag, layoutScale: layoutScale);
            })
            .toList(growable: false),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.tag, required this.layoutScale});

  final _ScoreChipData tag;
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
      child: Text(tag.text, maxLines: 2, style: TaqaUiStyles.scoreCardTag),
    );
  }
}
