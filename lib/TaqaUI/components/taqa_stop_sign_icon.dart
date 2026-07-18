import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaStopSignIcon extends StatelessWidget {
  const TaqaStopSignIcon({
    super.key,
    this.size = 12,
    this.color = TaqaUiColors.recordRed,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scaledSize = TaqaUiScale.w(size);
    return SizedBox.square(
      dimension: scaledSize,
      child: CustomPaint(
        painter: _TaqaStopSignPainter(
          color: color,
          strokeWidth: TaqaUiScale.w(1.2),
        ),
      ),
    );
  }
}

class _TaqaStopSignPainter extends CustomPainter {
  const _TaqaStopSignPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final path = Path();
    for (var index = 0; index < 8; index++) {
      final angle = -math.pi / 8 + index * math.pi / 4;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.miter,
    );

    final markPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, size.height * 0.27),
      Offset(center.dx, size.height * 0.57),
      markPaint,
    );
    canvas.drawCircle(
      Offset(center.dx, size.height * 0.75),
      strokeWidth * 0.52,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TaqaStopSignPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
