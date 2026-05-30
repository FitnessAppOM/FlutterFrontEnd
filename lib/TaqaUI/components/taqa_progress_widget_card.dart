import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

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
    const cardRadius = 16.0;
    const arcYOffset = 4.0;

    return AspectRatio(
      aspectRatio: 1.10,
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                          fontSize: 8,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    topRight ?? _TinyRightArrow(color: textColor),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: showArc
                        ? Transform.translate(
                            offset: const Offset(0, arcYOffset),
                            child: SizedBox(
                              width: 122,
                              height: 122,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size.square(122),
                                    painter: _OpenArcPainter(
                                      progress: clampedProgress,
                                      baseColor: baseArcColor,
                                      valueColor: valueArcColor,
                                    ),
                                  ),
                                  if (loading)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: textColor,
                                      ),
                                    )
                                  else
                                    Text(
                                      valueText,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                        height: 1,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : (loading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: textColor,
                                  ),
                                )
                              : Text(
                                  valueText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    height: 1,
                                  ),
                                )),
                  ),
                ),
                Center(
                  child: Text(
                    goalText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 8,
                      fontWeight: FontWeight.w300,
                      color: textColor,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    const strokeWidth = 12.0;
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
