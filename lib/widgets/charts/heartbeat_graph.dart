import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HeartbeatGraph extends StatelessWidget {
  const HeartbeatGraph({
    super.key,
    this.title = "HEART RATE",
    this.valueText = "119",
    this.unitText = "BPM",
  });

  final String title;
  final String valueText;
  final String unitText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: _HeartbeatPainter(),
            size: Size.infinite,
          ),
          Positioned(
            left: 16,
            top: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      valueText,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        unitText,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white60,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const lines = 4;
    for (int i = 0; i <= lines; i++) {
      final y = (size.height / lines) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final midY = size.height * 0.55;
    final amp = size.height * 0.22;
    final points = <Offset>[];
    const spikes = [0.12, 0.18, 0.42, 0.56, 0.78, 0.86];

    for (int i = 0; i <= 120; i++) {
      final t = i / 120;
      var y = midY + sin(t * pi * 4) * amp * 0.15;
      for (final s in spikes) {
        if ((t - s).abs() < 0.015) {
          y = midY - amp * 1.4;
        }
        if ((t - s - 0.02).abs() < 0.015) {
          y = midY + amp * 0.6;
        }
      }
      points.add(Offset(t * size.width, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final end = points.last;
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    _drawDashedLine(canvas, Offset(end.dx, 12), Offset(end.dx, size.height - 12), dashPaint);

    final glow = Paint()
      ..color = const Color(0xFF35B6FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glow);

    final line = Paint()
      ..color = const Color(0xFF35B6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(end, 4.2, dotPaint);
    final ringPaint = Paint()
      ..color = const Color(0xFF35B6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(end, 6.5, ringPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = sqrt(dx * dx + dy * dy);
    var dist = 0.0;
    while (dist < len) {
      final t1 = dist / len;
      final t2 = (dist + dash) / len;
      final p1 = Offset(start.dx + dx * t1, start.dy + dy * t1);
      final p2 = Offset(start.dx + dx * t2, start.dy + dy * t2);
      canvas.drawLine(p1, p2, paint);
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
