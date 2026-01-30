import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RecoveryGauge extends StatelessWidget {
  const RecoveryGauge({
    super.key,
    required this.score,
  });

  final double? score;

  @override
  Widget build(BuildContext context) {
    final hasData = score != null;
    final value = (score ?? 0).clamp(0, 100).toDouble();
    final label = hasData ? _labelForScore(value) : "No data";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            width: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: _GaugePainter(value: value),
                  size: const Size(190, 190),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toStringAsFixed(0),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasData
                ? "${value.toStringAsFixed(0)}% Ready to Perform"
                : "No data yet for this day",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _labelForScore(double value) {
    if (value >= 67) return "Good Recovery";
    if (value >= 34) return "Moderate Recovery";
    return "Low Recovery";
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;
    final progress = sweepAngle * (value / 100);

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      basePaint,
    );

    if (progress > 0.001) {
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + progress,
        colors: const [
          Color(0xFF2ECC71),
          Color(0xFFB8E91E),
        ],
      );
      final progressPaint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progress,
        false,
        progressPaint,
      );

      final dotAngle = startAngle + progress;
      final dot = Offset(
        center.dx + cos(dotAngle) * radius,
        center.dy + sin(dotAngle) * radius,
      );
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(dot, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
