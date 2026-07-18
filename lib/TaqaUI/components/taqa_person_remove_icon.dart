import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';

class TaqaPersonRemoveIcon extends StatelessWidget {
  const TaqaPersonRemoveIcon({
    super.key,
    this.color = const Color(0xFF1F1F1F),
    this.loading = false,
  });

  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TaqaUiScale.w(16),
      height: TaqaUiScale.h(12),
      child: loading
          ? FittedBox(
              child: CircularProgressIndicator(
                strokeWidth: TaqaUiScale.w(1.5),
                color: color,
              ),
            )
          : CustomPaint(painter: _TaqaPersonRemovePainter(color: color)),
    );
  }
}

class _TaqaPersonRemovePainter extends CustomPainter {
  const _TaqaPersonRemovePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unitX = size.width / 16;
    final unitY = size.height / 12;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(4 * unitX, 2.5 * unitY),
        width: 4 * unitX,
        height: 4 * unitY,
      ),
      paint,
    );

    final body = Path()
      ..moveTo(0, 12 * unitY)
      ..cubicTo(0, 8.6 * unitY, 1.7 * unitX, 7 * unitY, 4 * unitX, 7 * unitY)
      ..cubicTo(
        6.3 * unitX,
        7 * unitY,
        8 * unitX,
        8.6 * unitY,
        8 * unitX,
        12 * unitY,
      )
      ..close();
    canvas.drawPath(body, paint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10 * unitX, 5.25 * unitY, 6 * unitX, 1.5 * unitY),
        Radius.circular(0.75 * unitY),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TaqaPersonRemovePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
