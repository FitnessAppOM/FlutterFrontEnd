import 'dart:math';
import 'package:flutter/material.dart';

class DualLineChart extends StatelessWidget {
  const DualLineChart({
    super.key,
    required this.aValues,
    required this.bValues,
    required this.aColor,
    required this.bColor,
    this.height = 170,
  });

  final List<double?> aValues;
  final List<double?> bValues;
  final Color aColor;
  final Color bColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DualLinePainter(
          aValues: aValues,
          bValues: bValues,
          aColor: aColor,
          bColor: bColor,
        ),
      ),
    );
  }
}

class _DualLinePainter extends CustomPainter {
  _DualLinePainter({
    required this.aValues,
    required this.bValues,
    required this.aColor,
    required this.bColor,
  });

  final List<double?> aValues;
  final List<double?> bValues;
  final Color aColor;
  final Color bColor;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [
      ...aValues.whereType<double>(),
      ...bValues.whereType<double>(),
    ];
    if (all.isEmpty) return;
    var minVal = all.reduce(min);
    var maxVal = all.reduce(max);
    if (minVal == maxVal) {
      minVal -= 1;
      maxVal += 1;
    }
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    const padding = 10.0;
    final chart = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    _drawGrid(canvas, chart);
    _drawSeries(canvas, chart, aValues, aColor, minVal, range);
    _drawSeries(canvas, chart, bValues, bColor, minVal, range);
  }

  void _drawSeries(
    Canvas canvas,
    Rect chart,
    List<double?> values,
    Color color,
    double minVal,
    double range,
  ) {
    if (values.isEmpty) return;

    final segments = _segments(values, chart, minVal, range);
    for (final seg in segments) {
      final linePath = _smoothPath(seg);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, glowPaint);

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, linePaint);
    }

    final last = _lastPoint(values, chart, minVal, range);
    if (last != null) {
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(last, 3.6, dotPaint);
    }
  }

  void _drawGrid(Canvas canvas, Rect chart) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const lines = 4;
    for (int i = 0; i <= lines; i++) {
      final y = chart.top + (chart.height / lines) * i;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
  }

  List<List<Offset>> _segments(
    List<double?> values,
    Rect chart,
    double minVal,
    double range,
  ) {
    final segs = <List<Offset>>[];
    List<Offset> current = [];
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        if (current.isNotEmpty) {
          segs.add(current);
          current = [];
        }
        continue;
      }
      final x = chart.left + (i / (values.length - 1)) * chart.width;
      final y = chart.bottom - ((v - minVal) / range) * chart.height;
      current.add(Offset(x, y));
    }
    if (current.isNotEmpty) segs.add(current);
    return segs;
  }

  Offset? _lastPoint(
    List<double?> values,
    Rect chart,
    double minVal,
    double range,
  ) {
    for (int i = values.length - 1; i >= 0; i--) {
      final v = values[i];
      if (v == null) continue;
      final x = chart.left + (i / (values.length - 1)) * chart.width;
      final y = chart.bottom - ((v - minVal) / range) * chart.height;
      return Offset(x, y);
    }
    return null;
  }

  Path _smoothPath(List<Offset> points) {
    if (points.length < 2) {
      return Path()..addOval(Rect.fromCircle(center: points.first, radius: 1));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final control = Offset((p0.dx + p1.dx) / 2, p0.dy);
      final control2 = Offset((p0.dx + p1.dx) / 2, p1.dy);
      path.cubicTo(control.dx, control.dy, control2.dx, control2.dy, p1.dx, p1.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _DualLinePainter oldDelegate) {
    return oldDelegate.aValues != aValues ||
        oldDelegate.bValues != bValues ||
        oldDelegate.aColor != aColor ||
        oldDelegate.bColor != bColor;
  }
}
