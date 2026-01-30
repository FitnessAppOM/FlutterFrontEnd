import 'dart:math';
import 'package:flutter/material.dart';

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 170,
    this.showPoints = false,
  });

  final List<double?> values;
  final Color color;
  final double height;
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(
          values: values,
          color: color,
          showPoints: showPoints,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.color,
    required this.showPoints,
  });

  final List<double?> values;
  final Color color;
  final bool showPoints;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final clean = values.whereType<double>().toList();
    if (clean.isEmpty) return;

    var minVal = clean.reduce(min);
    var maxVal = clean.reduce(max);
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

    final segments = _segments(chart, minVal, range);
    for (final seg in segments) {
      final linePath = _smoothPath(seg);
      final fillPath = Path.from(linePath)
        ..lineTo(seg.last.dx, chart.bottom)
        ..lineTo(seg.first.dx, chart.bottom)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(chart);
      canvas.drawPath(fillPath, fillPaint);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, glowPaint);

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, linePaint);
    }

    if (showPoints) {
      final pointPaint = Paint()..color = Colors.white;
      final ringPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final points = _allPoints(chart, minVal, range);
      for (final p in points) {
        canvas.drawCircle(p, 3.4, pointPaint);
        canvas.drawCircle(p, 5.2, ringPaint);
      }
    }

    final last = _lastPoint(chart, minVal, range);
    if (last != null) {
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(last, 4.2, dotPaint);
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

  List<List<Offset>> _segments(Rect chart, double minVal, double range) {
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

  Offset? _lastPoint(Rect chart, double minVal, double range) {
    for (int i = values.length - 1; i >= 0; i--) {
      final v = values[i];
      if (v == null) continue;
      final x = chart.left + (i / (values.length - 1)) * chart.width;
      final y = chart.bottom - ((v - minVal) / range) * chart.height;
      return Offset(x, y);
    }
    return null;
  }

  List<Offset> _allPoints(Rect chart, double minVal, double range) {
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final x = chart.left + (i / (values.length - 1)) * chart.width;
      final y = chart.bottom - ((v - minVal) / range) * chart.height;
      points.add(Offset(x, y));
    }
    return points;
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
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.showPoints != showPoints;
  }
}
