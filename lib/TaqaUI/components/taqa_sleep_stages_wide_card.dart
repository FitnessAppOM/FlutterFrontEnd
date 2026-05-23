import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
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
    const arcSize = 122.0;
    const arcStrokeWidth = 12.0;
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: arcSize,
                height: arcSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(arcSize),
                      painter: _OpenStageArcPainter(
                        lightPct: nLight,
                        deepPct: nDeep,
                        remPct: nRem,
                        strokeWidth: arcStrokeWidth,
                        baseColor: const Color(0xFFCECED0),
                        lightColor: lightColor,
                        deepColor: deepColor,
                        remColor: remColor,
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: const TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.unnamedColor1c1d17,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(
                      color: lightColor,
                      label: 'Light',
                      value: '${(safeLight * 100).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 8),
                    _legendRow(
                      color: deepColor,
                      label: 'Deep',
                      value: '${(safeDeep * 100).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 8),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17,
              height: 1.0,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: TaqaUiColors.unnamedColor1c1d17,
            height: 1.0,
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
