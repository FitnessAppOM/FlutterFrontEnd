import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaSleepStagesWideCard extends StatelessWidget {
  const TaqaSleepStagesWideCard({
    super.key,
    required this.title,
    required this.lightPct,
    required this.deepPct,
    required this.remPct,
    this.centerLabel = 'Stages',
  });

  final String title;
  final double lightPct;
  final double deepPct;
  final double remPct;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final arcSize = TaqaUiScale.w(120);
    final strokeWidth = TaqaUiScale.w(12);
    final safeLight = lightPct.clamp(0.0, 1.0).toDouble();
    final safeDeep = deepPct.clamp(0.0, 1.0).toDouble();
    final safeRem = remPct.clamp(0.0, 1.0).toDouble();
    final total = safeLight + safeDeep + safeRem;
    final normalizer = total > 1.0 ? total : 1.0;
    final nLight = safeLight / normalizer;
    final nDeep = safeDeep / normalizer;
    final nRem = safeRem / normalizer;

    const lightColor = Color(0xFF4DD6C8);
    const deepColor = Color(0xFF3F9DEB);
    const remColor = Color(0xFF5D47E4);

    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(15, 10, 15, 15),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17,
              letterSpacing: 0,
              height: 10 / 8,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: arcSize,
                height: arcSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(arcSize),
                      painter: _OpenStageArcPainter(
                        lightPct: nLight,
                        deepPct: nDeep,
                        remPct: nRem,
                        strokeWidth: strokeWidth,
                        baseColor: const Color(0xFFCECED0),
                        lightColor: lightColor,
                        deepColor: deepColor,
                        remColor: remColor,
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.unnamedColor1c1d17,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: TaqaUiScale.w(20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(
                      color: lightColor,
                      label: 'Light',
                      value: '${(safeLight * 100).toStringAsFixed(0)}%',
                    ),
                    SizedBox(height: TaqaUiScale.h(6)),
                    _legendRow(
                      color: deepColor,
                      label: 'Deep',
                      value: '${(safeDeep * 100).toStringAsFixed(0)}%',
                    ),
                    SizedBox(height: TaqaUiScale.h(6)),
                    _legendRow(
                      color: remColor,
                      label: 'REM',
                      value: '${(safeRem * 100).toStringAsFixed(0)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: TaqaUiScale.w(8),
          height: TaqaUiScale.h(8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: TaqaUiScale.w(8)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17,
              letterSpacing: 0,
              height: 13 / 8,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(8),
            fontWeight: FontWeight.w400,
            color: TaqaUiColors.unnamedColor1c1d17,
            letterSpacing: 0,
            height: 13 / 8,
          ),
        ),
      ],
    );
  }
}

class _OpenStageArcPainter extends CustomPainter {
  const _OpenStageArcPainter({
    required this.lightPct,
    required this.deepPct,
    required this.remPct,
    required this.strokeWidth,
    required this.baseColor,
    required this.lightColor,
    required this.deepColor,
    required this.remColor,
  });

  final double lightPct;
  final double deepPct;
  final double remPct;
  final double strokeWidth;
  final Color baseColor;
  final Color lightColor;
  final Color deepColor;
  final Color remColor;

  @override
  void paint(Canvas canvas, Size size) {
    const start = 3 * math.pi / 4;
    const sweep = 3 * math.pi / 2;
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
    canvas.drawArc(rect, start, sweep, false, base);

    final stagePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    var cursor = start;
    if (lightPct > 0) {
      stagePaint.color = lightColor;
      final seg = sweep * lightPct;
      canvas.drawArc(rect, cursor, seg, false, stagePaint);
      cursor += seg;
    }
    if (deepPct > 0) {
      stagePaint.color = deepColor;
      final seg = sweep * deepPct;
      canvas.drawArc(rect, cursor, seg, false, stagePaint);
      cursor += seg;
    }
    if (remPct > 0) {
      stagePaint.color = remColor;
      final seg = sweep * remPct;
      canvas.drawArc(rect, cursor, seg, false, stagePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OpenStageArcPainter oldDelegate) {
    return oldDelegate.lightPct != lightPct ||
        oldDelegate.deepPct != deepPct ||
        oldDelegate.remPct != remPct ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.deepColor != deepColor ||
        oldDelegate.remColor != remColor;
  }
}
