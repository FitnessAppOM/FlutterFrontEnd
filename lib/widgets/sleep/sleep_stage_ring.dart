import 'dart:math';
import 'package:flutter/material.dart';

class SleepStageRing extends StatelessWidget {
  const SleepStageRing({
    super.key,
    required this.lightPct,
    required this.deepPct,
    required this.remPct,
    this.size = 120,
  });

  final double lightPct;
  final double deepPct;
  final double remPct;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _RingPainter(
          lightPct: lightPct,
          deepPct: deepPct,
          remPct: remPct,
        ),
        child: Center(
          child: Text(
            "Stages",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.lightPct,
    required this.deepPct,
    required this.remPct,
  });

  final double lightPct;
  final double deepPct;
  final double remPct;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final total = max(0.0, lightPct) + max(0.0, deepPct) + max(0.0, remPct);
    final bgPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (total <= 0) return;

    double start = -pi / 2;
    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final sweep = (pct / total) * 2 * pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }

    drawSegment(lightPct, const Color(0xFF7BD4FF));
    drawSegment(deepPct, const Color(0xFF9B8CFF));
    drawSegment(remPct, const Color(0xFF00BFA6));
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.lightPct != lightPct ||
        oldDelegate.deepPct != deepPct ||
        oldDelegate.remPct != remPct;
  }
}
