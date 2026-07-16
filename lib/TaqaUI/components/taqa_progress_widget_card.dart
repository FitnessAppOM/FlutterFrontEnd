import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_marquee_text.dart';

class TaqaProgressWidgetCard extends StatelessWidget {
  const TaqaProgressWidgetCard({
    super.key,
    required this.title,
    required this.valueText,
    required this.goalText,
    required this.progress,
    this.showArc = true,
    this.loading = false,
    this.onTap,
    this.topRight,
    this.lightSurface = true,
    this.goalScrollable = true,
  });

  final String title;
  final String valueText;
  final String goalText;
  final double progress;
  final bool showArc;
  final bool loading;
  final VoidCallback? onTap;
  final Widget? topRight;
  final bool lightSurface;

  /// Set false for a static status message (e.g. "No health data") rather
  /// than a real value — it should just show in full, never scroll,
  /// regardless of length. Only takes effect on arc cards (showArc: true);
  /// non-arc cards never scroll their goal text at all.
  final bool goalScrollable;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final surfaceColor = lightSurface
        ? TaqaUiColors.white
        : TaqaUiColors.charcoal;
    final textColor = lightSurface ? TaqaUiColors.charcoal : TaqaUiColors.white;
    final baseArcColor = lightSurface
        ? TaqaUiColors.lightGray
        : TaqaUiColors.graphite;
    final valueArcColor = lightSurface
        ? TaqaUiColors.charcoal
        : TaqaUiColors.lightGray;
    final targetCardWidth = TaqaUiScale.w(171);
    final targetCardHeight = TaqaUiScale.h(171);
    final targetArcSize = TaqaUiScale.w(129);
    final targetArcVisibleHeight = TaqaUiScale.h(114);
    final cardRadius = TaqaUiScale.r(15);
    final baseTitleFontSize = TaqaUiScale.sp(8);
    final baseGoalFontSize = TaqaUiScale.sp(10);
    final baseValueFontSize = TaqaUiScale.sp(25);
    final basePlainValueFontSize = TaqaUiScale.sp(32);
    final baseIndicatorSize = TaqaUiScale.w(16);

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(
            constraints.maxWidth / targetCardWidth,
            constraints.maxHeight / targetCardHeight,
          );
          final safeScale = scale.isFinite ? scale.clamp(0.0, 1.0) : 1.0;
          final cardWidth = targetCardWidth * safeScale;
          final cardHeight = targetCardHeight * safeScale;
          final titleFontSize = baseTitleFontSize * safeScale;
          final goalFontSize = baseGoalFontSize * safeScale;
          final valueFontSize =
              (showArc ? baseValueFontSize : basePlainValueFontSize) * safeScale;
          final plainValueFontWeight = FontWeight.w600;
          final indicatorSize = baseIndicatorSize * safeScale;
          final arcSize = targetArcSize * safeScale;
          final arcVisibleHeight = targetArcVisibleHeight * safeScale;
          final horizontalPadding = TaqaUiScale.w(16) * safeScale;
          final topPadding = TaqaUiScale.h(9) * safeScale;
          final bottomPadding = TaqaUiScale.h(2) * safeScale;
          final titleToArcGap = TaqaUiScale.h(8) * safeScale;
          final goalTopGap = TaqaUiScale.h(0) * safeScale;
          final goalOverlap = TaqaUiScale.h(6) * safeScale;
          final goalTextStyle = TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: goalFontSize,
            fontWeight: FontWeight.w300,
            color: textColor,
            height: 1.1,
          );
          // Text under 13 characters never goes near the cap/marquee path at
          // all below, so it can't be clipped by a measurement mismatch.
          const goalScrollThreshold = 13;
          // For text at/over the threshold, force a box no wider than the
          // real text's own first 12 characters, so it's always narrower
          // than the full string and reliably overflows into a scroll —
          // measuring a prefix of the actual text (same style) instead of
          // guessing a multiplier keeps this accurate to the real font.
          final goalCapWidth =
              (TextPainter(
                    text: TextSpan(
                      text: goalText.substring(
                        0,
                        math.min(goalScrollThreshold - 1, goalText.length),
                      ),
                      style: goalTextStyle,
                    ),
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: double.infinity))
                  .width;

          return Center(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(cardRadius),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                  letterSpacing: 0.2,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            topRight ?? _TinyRightArrow(color: textColor),
                          ],
                        ),
                        SizedBox(height: titleToArcGap),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Center(
                                child: SizedBox(
                                  width: arcSize,
                                  height: arcVisibleHeight,
                                  child: showArc
                                      ? ClipRect(
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
                                                    size:
                                                        Size(arcSize, arcSize),
                                                    painter: _OpenArcPainter(
                                                      progress:
                                                          clampedProgress,
                                                      baseColor: baseArcColor,
                                                      valueColor:
                                                          valueArcColor,
                                                    ),
                                                  ),
                                                  if (loading)
                                                    SizedBox(
                                                      width: indicatorSize,
                                                      height: indicatorSize,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: textColor,
                                                          ),
                                                    )
                                                  else
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                TaqaUiScale.w(
                                                                  16,
                                                                ) *
                                                                safeScale,
                                                          ),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          valueText,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                TaqaUiFontFamilies
                                                                    .interTight,
                                                            fontSize:
                                                                valueFontSize,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: textColor,
                                                            height: 1,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: loading
                                              ? SizedBox(
                                                  width: indicatorSize,
                                                  height: indicatorSize,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: textColor,
                                                      ),
                                                )
                                              : Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        TaqaUiScale.w(4) *
                                                            safeScale,
                                                  ),
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      valueText,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontFamily:
                                                            TaqaUiFontFamilies
                                                                .interTight,
                                                        fontSize:
                                                            valueFontSize,
                                                        fontWeight:
                                                            plainValueFontWeight,
                                                        color: textColor,
                                                        height: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                ),
                              ),
                              SizedBox(height: goalTopGap),
                              Transform.translate(
                                offset: Offset(0, -goalOverlap),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: TaqaUiScale.w(8) * safeScale,
                                  ),
                                  child: !showArc
                                      ? Text(
                                          goalText,
                                          textAlign: TextAlign.center,
                                          style: goalTextStyle,
                                        )
                                      : !goalScrollable ||
                                            goalText.length <
                                                goalScrollThreshold
                                      ? Text(
                                          goalText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: goalTextStyle,
                                        )
                                      : Center(
                                          child: SizedBox(
                                            width: goalCapWidth,
                                            child: TaqaMarqueeText(
                                              text: goalText,
                                              textAlign: TextAlign.center,
                                              style: goalTextStyle,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _OpenArcPainter extends CustomPainter {
  const _OpenArcPainter({
    required this.progress,
    required this.baseColor,
    required this.valueColor,
  });

  final double progress;
  final Color baseColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.112;
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
      ..color = baseColor;

    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = valueColor;

    const start = 3 * math.pi / 4;
    const sweep = 3 * math.pi / 2;

    canvas.drawArc(rect, start, sweep, false, base);
    if (progress > 0) {
      canvas.drawArc(rect, start, sweep * progress, false, value);
    }
  }

  @override
  bool shouldRepaint(covariant _OpenArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.valueColor != valueColor;
  }
}

class _TinyRightArrow extends StatelessWidget {
  const _TinyRightArrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: 4,
      child: CustomPaint(painter: _TinyRightArrowPainter(color: color)),
    );
  }
}

class _TinyRightArrowPainter extends CustomPainter {
  const _TinyRightArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
