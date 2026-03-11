import 'cardio_map.dart';

const int kCardioSnapshotWidth = 900;
const int kCardioSnapshotHeight = 540;
const int kCardioSnapshotPadding = 70;

String buildCardioSnapshotUrlDefault({
  required String token,
  required List<CardioPoint> route,
}) {
  return buildCardioSnapshotUrl(
    token: token,
    route: route,
    width: kCardioSnapshotWidth,
    height: kCardioSnapshotHeight,
    padding: kCardioSnapshotPadding,
  );
}

String buildCardioSnapshotUrl({
  required String token,
  required List<CardioPoint> route,
  required int width,
  required int height,
  int padding = 40,
  int lineWidth = 5,
  String lineColor = '2D7CFF',
  double lineOpacity = 0.85,
  String pausedLineColor = 'E24B4B',
  String style = 'mapbox/streets-v12',
}) {
  if (token.isEmpty || route.isEmpty) return '';
  final safePadding = _clampPadding(padding, width, height);
  final start = route.first;
  final end = route.last;
  final startMarker = _markerOverlay(
    label: 's',
    color: '00C853',
    point: start,
  );
  final endMarker = _markerOverlay(
    label: 'f',
    color: '111111',
    point: end,
  );
  final overlays = <String>[startMarker, endMarker];
  final hasPaused = route.any((p) => p.paused);
  if (hasPaused) {
    final segments = splitCardioRouteSegments(route);
    for (final segment in segments) {
      if (segment.points.length < 2) continue;
      final encoded = encodeCardioPolyline(sampleCardioRoute(segment.points));
      final color = segment.paused ? pausedLineColor : lineColor;
      overlays.add(Uri.encodeComponent(
        'path-$lineWidth+$color-$lineOpacity($encoded)',
      ));
    }
  } else {
    final encoded = encodeCardioPolyline(sampleCardioRoute(route));
    overlays.add(Uri.encodeComponent(
      'path-$lineWidth+$lineColor-$lineOpacity($encoded)',
    ));
  }
  final overlayString = overlays.join(',');
  return 'https://api.mapbox.com/styles/v1/$style/static/'
      '$overlayString/auto/${width}x$height?access_token=$token&padding=$safePadding';
}

List<CardioPoint> sampleCardioRoute(List<CardioPoint> route) {
  if (route.length <= 2) return route;
  final deduped = <CardioPoint>[];
  CardioPoint? last;
  for (final p in route) {
    if (last == null || last.lat != p.lat || last.lng != p.lng) {
      deduped.add(p);
      last = p;
    }
  }
  const maxPoints = 600;
  if (deduped.length <= maxPoints) return deduped;
  final step = (deduped.length / maxPoints).ceil();
  final sampled = <CardioPoint>[];
  for (var i = 0; i < deduped.length; i += step) {
    sampled.add(deduped[i]);
  }
  if (sampled.last.lat != deduped.last.lat ||
      sampled.last.lng != deduped.last.lng) {
    sampled.add(deduped.last);
  }
  return sampled;
}

List<CardioRouteSegment> splitCardioRouteSegments(List<CardioPoint> route) {
  final segments = <CardioRouteSegment>[];
  CardioRouteSegment? current;
  for (final p in route) {
    final paused = p.paused;
    if (current == null || current.paused != paused) {
      current = CardioRouteSegment(paused: paused, points: []);
      segments.add(current);
    }
    current.points.add(p);
  }
  return segments;
}

class CardioRouteSegment {
  final bool paused;
  final List<CardioPoint> points;

  CardioRouteSegment({required this.paused, required this.points});
}

String encodeCardioPolyline(List<CardioPoint> points) {
  int lastLat = 0;
  int lastLng = 0;
  final StringBuffer result = StringBuffer();

  for (final p in points) {
    final lat = (p.lat * 1e5).round();
    final lng = (p.lng * 1e5).round();
    final dLat = lat - lastLat;
    final dLng = lng - lastLng;
    _encodeValue(dLat, result);
    _encodeValue(dLng, result);
    lastLat = lat;
    lastLng = lng;
  }
  return result.toString();
}

void _encodeValue(int value, StringBuffer out) {
  int v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    final char = (0x20 | (v & 0x1f)) + 63;
    out.writeCharCode(char);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}

int _clampPadding(int padding, int width, int height) {
  if (padding < 0) return 0;
  final maxPadX = (width / 2).floor();
  final maxPadY = (height / 2).floor();
  final maxPad = maxPadX < maxPadY ? maxPadX : maxPadY;
  if (padding > maxPad) return maxPad;
  return padding;
}

String _markerOverlay({
  required String? label,
  required String color,
  required CardioPoint point,
}) {
  final lng = _formatCoord(point.lng);
  final lat = _formatCoord(point.lat);
  final marker = label == null || label.trim().isEmpty
      ? 'pin-s'
      : 'pin-s-${label.toLowerCase()}';
  return '$marker+$color($lng,$lat)';
}

String _formatCoord(double value) {
  return value.toStringAsFixed(6);
}
