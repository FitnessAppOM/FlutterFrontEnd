import 'dart:math';
import 'cardio_map.dart';

const int kCardioSnapshotWidth = 900;
const int kCardioSnapshotHeight = 540;
const int kCardioSnapshotPadding = 70;
const int kCardioMasterSnapshotWidth = 1200;
const int kCardioMasterSnapshotHeight = 900;

String buildCardioSnapshotUrlDefault({
  required String token,
  required List<CardioPoint> route,
}) {
  return buildCardioSnapshotUrlFitBounds(
    token: token,
    route: route,
    width: kCardioSnapshotWidth,
    height: kCardioSnapshotHeight,
    padding: kCardioSnapshotPadding,
    zoomOut: 0.6,
  );
}

String buildCardioSnapshotUrlMaster({
  required String token,
  required List<CardioPoint> route,
}) {
  return buildCardioSnapshotUrlFitBounds(
    token: token,
    route: route,
    width: kCardioMasterSnapshotWidth,
    height: kCardioMasterSnapshotHeight,
    padding: 90,
    lineWidth: 6,
    zoomOut: 1.5,
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
  final overlayString = _buildOverlayString(
    route: route,
    lineWidth: lineWidth,
    lineColor: lineColor,
    pausedLineColor: pausedLineColor,
    lineOpacity: lineOpacity,
  );
  return 'https://api.mapbox.com/styles/v1/$style/static/'
      '$overlayString/auto/${width}x$height?access_token=$token&padding=$safePadding';
}

String buildCardioSnapshotUrlFitBounds({
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
  double zoomOut = 0.0,
}) {
  if (token.isEmpty || route.isEmpty) return '';
  final bounds = _computeBounds(route);
  if (bounds == null) return '';
  final safePadding = _clampPadding(padding, width, height);
  final zoom = _computeZoom(
    bounds: bounds,
    width: width,
    height: height,
    padding: safePadding,
  ) - zoomOut;
  final centerLat = (bounds.minLat + bounds.maxLat) / 2;
  final centerLng = (bounds.minLng + bounds.maxLng) / 2;
  final safeZoom = zoom.clamp(0.0, 20.0);
  final overlayString = _buildOverlayString(
    route: route,
    lineWidth: lineWidth,
    lineColor: lineColor,
    pausedLineColor: pausedLineColor,
    lineOpacity: lineOpacity,
  );
  return 'https://api.mapbox.com/styles/v1/$style/static/'
      '$overlayString/${_formatCoord(centerLng)},${_formatCoord(centerLat)},${safeZoom.toStringAsFixed(2)}/${width}x$height?access_token=$token';
}

String buildCardioSnapshotUrlForSize({
  required String token,
  required List<CardioPoint> route,
  required double widthPx,
  required double heightPx,
  double dpr = 1.0,
  int minSize = 320,
  int maxSize = 1280,
  int padding = 80,
  int lineWidth = 6,
  double zoomOut = 1.0,
  String lineColor = '2D7CFF',
  double lineOpacity = 0.85,
  String pausedLineColor = 'E24B4B',
  String style = 'mapbox/streets-v12',
}) {
  final reqW = (widthPx * dpr).round().clamp(minSize, maxSize);
  final reqH = (heightPx * dpr).round().clamp(minSize, maxSize);
  return buildCardioSnapshotUrlFitBounds(
    token: token,
    route: route,
    width: reqW,
    height: reqH,
    padding: padding,
    lineWidth: lineWidth,
    lineColor: lineColor,
    lineOpacity: lineOpacity,
    pausedLineColor: pausedLineColor,
    style: style,
    zoomOut: zoomOut,
  );
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

String _buildOverlayString({
  required List<CardioPoint> route,
  required int lineWidth,
  required String lineColor,
  required String pausedLineColor,
  required double lineOpacity,
}) {
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
  return overlays.join(',');
}

_Bounds? _computeBounds(List<CardioPoint> route) {
  if (route.isEmpty) return null;
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
  return _Bounds(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
}

double _computeZoom({
  required _Bounds bounds,
  required int width,
  required int height,
  required int padding,
}) {
  const tileSize = 512.0;
  final pxWidth = (width - padding * 2).clamp(1, width).toDouble();
  final pxHeight = (height - padding * 2).clamp(1, height).toDouble();
  final lngDelta = (bounds.maxLng - bounds.minLng).abs().clamp(1e-6, 360.0);
  final latDelta = (bounds.maxLat - bounds.minLat).abs().clamp(1e-6, 180.0);
  final latRadMax = _latToRad(bounds.maxLat);
  final latRadMin = _latToRad(bounds.minLat);
  final mercMax = log(tan(pi / 4 + latRadMax / 2));
  final mercMin = log(tan(pi / 4 + latRadMin / 2));
  final mercDelta = (mercMax - mercMin).abs().clamp(1e-6, pi);
  final zoomX = log((pxWidth * 360) / (lngDelta * tileSize)) / ln2;
  final zoomY = log((pxHeight * 2 * pi) / (mercDelta * tileSize)) / ln2;
  final zoom = min(zoomX, zoomY).clamp(0.0, 20.0);
  return zoom;
}

double _latToRad(double lat) => lat * pi / 180.0;

class _Bounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _Bounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
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
