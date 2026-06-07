import 'package:flutter/material.dart';
import '../../../widgets/cardio/cardio_map.dart';

class ModelMapCard extends StatelessWidget {
  const ModelMapCard({
    super.key,
    required this.snapshotUrl,
    required this.overlay,
    this.mapOpacity = 1.0,
  });

  final String snapshotUrl;
  final Widget overlay;
  final double mapOpacity;

  @override
  Widget build(BuildContext context) {
    final hasMap = snapshotUrl.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0B0F1A),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasMap)
            Opacity(
              opacity: mapOpacity.clamp(0.0, 1.0),
              child: Image.network(
                snapshotUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => _mapFallback(),
              ),
            )
          else
            _mapFallback(),
          Positioned.fill(child: overlay),
        ],
      ),
    );
  }

  Widget _mapFallback() {
    return Container(
      color: const Color(0xFF0E1A33),
      child: const Center(
        child: Icon(Icons.map, color: Colors.white54, size: 36),
      ),
    );
  }
}

class ModelMetricsColumn extends StatelessWidget {
  const ModelMetricsColumn({
    super.key,
    required this.durationLabel,
    required this.showDistance,
    required this.distanceLabel,
    required this.paceLabel,
  });

  final String durationLabel;
  final bool showDistance;
  final String distanceLabel;
  final String paceLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ModelMetricPill(label: "Duration", value: durationLabel),
        if (showDistance)
          ModelMetricPill(label: "Distance", value: distanceLabel),
        ModelMetricPill(label: "Pace", value: paceLabel),
      ],
    );
  }
}

class ModelHeader extends StatelessWidget {
  const ModelHeader({
    super.key,
    required this.appName,
    required this.userName,
    required this.dateLabel,
  });

  final String appName;
  final String? userName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D7CFF), Color(0xFF48E1B9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.fitness_center, color: Colors.black, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
              ),
              Text(
                userName != null && userName!.trim().isNotEmpty
                    ? userName!
                    : 'Cardio Achievement',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            dateLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class ModelMetricPill extends StatelessWidget {
  const ModelMetricPill({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
        ),
      ],
    );
  }
}

class RouteTraceCanvas extends StatelessWidget {
  const RouteTraceCanvas({
    super.key,
    required this.route,
    this.showMarkers = false,
    this.lineWidth = 4.5,
    this.padding = 24,
  });

  final List<CardioPoint> route;
  final bool showMarkers;
  final double lineWidth;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RouteTracePainter(
        route: route,
        showMarkers: showMarkers,
        lineWidth: lineWidth,
        padding: padding,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RouteTracePainter extends CustomPainter {
  _RouteTracePainter({
    required this.route,
    required this.showMarkers,
    required this.lineWidth,
    required this.padding,
  });

  final List<CardioPoint> route;
  final bool showMarkers;
  final double lineWidth;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    final bounds = _TraceBounds.from(route);
    if (!bounds.isValid) return;
    final w = (size.width - padding * 2).clamp(1.0, size.width);
    final h = (size.height - padding * 2).clamp(1.0, size.height);
    Offset mapPoint(CardioPoint p) {
      final x = (p.lng - bounds.minLng) / bounds.lngSpan;
      final y = (bounds.maxLat - p.lat) / bounds.latSpan;
      return Offset(padding + (x * w), padding + (y * h));
    }

    final activePaint = Paint()
      ..color = const Color(0xFF2D7CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pausedPaint = Paint()
      ..color = const Color(0xFFE24B4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path? path;
    bool? paused;
    for (final p in route) {
      if (paused == null || paused != p.paused) {
        if (path != null && path!.computeMetrics().isNotEmpty) {
          canvas.drawPath(path!, paused == true ? pausedPaint : activePaint);
        }
        path = Path()..moveTo(mapPoint(p).dx, mapPoint(p).dy);
        paused = p.paused;
      } else {
        final pt = mapPoint(p);
        path!.lineTo(pt.dx, pt.dy);
      }
    }
    if (path != null && path!.computeMetrics().isNotEmpty) {
      canvas.drawPath(path!, paused == true ? pausedPaint : activePaint);
    }

    if (showMarkers) {
      final start = route.first;
      final end = route.last;
      final startOffset = mapPoint(start);
      final endOffset = mapPoint(end);
      final startPaint = Paint()
        ..color = const Color(0xFF00C853)
        ..style = PaintingStyle.fill;
      final endPaint = Paint()
        ..color = const Color(0xFF111111)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(startOffset, 7.5, startPaint);
      canvas.drawCircle(endOffset, 7.5, endPaint);

      _drawMarkerLabel(canvas, startOffset, 'S');
      _drawMarkerLabel(canvas, endOffset, 'F');
    }
  }

  @override
  bool shouldRepaint(covariant _RouteTracePainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.showMarkers != showMarkers ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.padding != padding;
  }

  void _drawMarkerLabel(Canvas canvas, Offset center, String label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final offset = center - Offset(tp.width / 2, tp.height / 2);
    tp.paint(canvas, offset);
  }
}

class _TraceBounds {
  _TraceBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool get isValid => latSpan > 0 && lngSpan > 0;
  double get latSpan => (maxLat - minLat).abs().clamp(1e-6, 180.0);
  double get lngSpan => (maxLng - minLng).abs().clamp(1e-6, 360.0);

  static _TraceBounds from(List<CardioPoint> route) {
    double minLat = route.first.lat;
    double maxLat = route.first.lat;
    double minLng = route.first.lng;
    double maxLng = route.first.lng;
    for (final p in route) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    return _TraceBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }
}
