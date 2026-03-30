import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../theme/app_theme.dart';
import '../common/gradient_bubble_button.dart';
import 'cardio_map_controls.dart';

class CardioMap extends StatefulWidget {
  const CardioMap({
    super.key,
    required this.hasToken,
    required this.expanded,
    this.height,
    this.initialDistanceMeters,
    this.initialSpeedKmh,
    this.initialRoute,
    this.onStart,
    this.onCountdownStart,
    this.onPause,
    this.onFinish,
    this.onClose,
    this.onMetrics,
    this.onRoute,
    this.steps,
    this.elapsedSeconds,
    this.running,
    this.trackingEnabled = true,
    this.countdownActive = false,
  });

  final bool hasToken;
  final bool expanded;
  final double? height;
  final double? initialDistanceMeters;
  final double? initialSpeedKmh;
  final List<CardioPoint>? initialRoute;
  final VoidCallback? onStart;
  final VoidCallback? onCountdownStart;
  final VoidCallback? onPause;
  final VoidCallback? onFinish;
  final VoidCallback? onClose;
  final ValueChanged<CardioMetrics>? onMetrics;
  final ValueChanged<List<CardioPoint>>? onRoute;
  final int? steps;
  final int? elapsedSeconds;
  final bool? running;
  final bool trackingEnabled;
  final bool countdownActive;

  @override
  State<CardioMap> createState() => _CardioMapState();
}

class _CardioMapState extends State<CardioMap> with WidgetsBindingObserver {
  MapboxMap? _map;
  bool _disposed = false;
  StreamSubscription<geo.Position>? _positionSub;
  PolylineAnnotationManager? _polylineManager;
  final List<_RouteSegment> _segments = [];
  final List<Position> _routePositions = [];
  geo.Position? _lastPosition;
  DateTime? _lastPositionTime;
  double _distanceMeters = 0;
  double _speedKmh = 0;
  bool _tracking = false;
  double _movedMetersSinceStart = 0;
  final List<_TimedPosition> _recentPositions = [];
  bool _hasTrackingData = false;
  bool _ignoreNextDistance = false;
  bool _pausedTracking = false;
  static const int _activeLineColor = 0xFF2D7CFF;
  static const int _pausedLineColor = 0xFFE24B4B;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyInitialSnapshot(force: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CardioMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDistanceMeters != oldWidget.initialDistanceMeters ||
        widget.initialSpeedKmh != oldWidget.initialSpeedKmh ||
        widget.initialRoute != oldWidget.initialRoute) {
      _applyInitialSnapshot(force: false);
    }
    if (widget.expanded && !oldWidget.expanded) {
      _recenterWithRetry();
    }
    if (!widget.trackingEnabled && oldWidget.trackingEnabled) {
      _pauseTracking();
    }
    if (widget.running != oldWidget.running ||
        widget.countdownActive != oldWidget.countdownActive) {
      final nowRunning = widget.running ?? false;
      final shouldPause =
          !(nowRunning || widget.countdownActive) && widget.trackingEnabled;
      _setPausedTracking(shouldPause);
      if (nowRunning || widget.countdownActive) {
        _ignoreNextDistance = true;
      }
    }
    if (widget.trackingEnabled && (widget.running ?? false) && !_tracking) {
      _ignoreNextDistance = true;
      _startTracking();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      if (widget.expanded) {
        _recenterWithRetry();
      }
      if (widget.trackingEnabled &&
          ((widget.running ?? false) || widget.countdownActive || _tracking)) {
        _ignoreNextDistance = true;
        _pauseTracking();
        _startTracking();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasToken) {
      return _mapPlaceholder(
        "Mapbox token missing",
        "Add MAPBOX_PUBLIC_KEY to .env",
      );
    }

    final targetHeight = widget.height ?? (widget.expanded ? 380.0 : 220.0);

    return AnimatedContainer(
      height: targetHeight,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dividerDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.expanded ? 0.35 : 0.22),
            blurRadius: widget.expanded ? 28 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            key: const ValueKey("cardio-map"),
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(2.3522, 48.8566)),
              zoom: 11.5,
            ),
            onMapCreated: (mapboxMap) {
              _map = mapboxMap;
              try {
                mapboxMap.gestures.updateSettings(
                  GesturesSettings(
                    scrollEnabled: true,
                    pinchToZoomEnabled: true,
                    rotateEnabled: true,
                    pitchEnabled: true,
                  ),
                );
              } catch (_) {
                // Ignore if gestures settings are not available.
              }
              _enableUserLocation();
              _redrawSeededRoute();
              _recenterWithRetry();
            },
          ),
          IgnorePointer(
            ignoring: true,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              opacity: widget.expanded ? 0.0 : 0.25,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: CardioMapControls(
              distanceKm: _distanceMeters / 1000.0,
              speedKmh: _speedKmh,
              steps: widget.steps,
              elapsedSeconds: widget.elapsedSeconds,
              running: widget.running,
              onCountdownStart: () {
                _startTracking();
                widget.onCountdownStart?.call();
              },
              onStart: () {
                _startTracking();
                widget.onStart?.call();
              },
              onPause: () {
                _setPausedTracking(true);
                widget.onPause?.call();
              },
              onFinish: () {
                widget.onRoute?.call(_buildRoutePointsPayload());
                widget.onFinish?.call();
                _finishTracking();
              },
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GradientBubbleButton(
              icon: Icons.close_rounded,
              size: 42,
              gradient: const LinearGradient(
                colors: [Color(0x33FFFFFF), Color(0x55D1E9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: widget.onClose,
            ),
          ),
        ],
      ),
    );
  }

  void _applyInitialSnapshot({required bool force}) {
    var changed = false;

    final initialDistanceMeters = widget.initialDistanceMeters;
    if (initialDistanceMeters != null &&
        (force || (!_tracking && initialDistanceMeters > _distanceMeters))) {
      _distanceMeters = initialDistanceMeters;
      changed = true;
    }

    final initialSpeedKmh = widget.initialSpeedKmh;
    if (initialSpeedKmh != null &&
        (force || (!_tracking && initialSpeedKmh > _speedKmh))) {
      _speedKmh = initialSpeedKmh;
      changed = true;
    }

    final route = widget.initialRoute;
    final canSeedRoute =
        route != null &&
        route.isNotEmpty &&
        (force || (!_tracking && route.length > _routePositions.length));
    if (canSeedRoute) {
      _seedRouteFromSnapshot(route);
      changed = true;
      if (_map != null) {
        unawaited(_redrawSeededRoute());
      }
    }

    if (changed) {
      _hasTrackingData = _routePositions.isNotEmpty || _distanceMeters > 0.1;
      if (!force && mounted) {
        setState(() {});
      }
    }
  }

  void _seedRouteFromSnapshot(List<CardioPoint> route) {
    _routePositions
      ..clear()
      ..addAll(route.map((p) => Position(p.lng, p.lat)));
    _segments.clear();
    if (route.isEmpty) return;

    _RouteSegment? activeSegment;
    Position? previous;
    for (final point in route) {
      final mapped = Position(point.lng, point.lat);
      if (activeSegment == null || activeSegment.paused != point.paused) {
        activeSegment = _RouteSegment(paused: point.paused, points: []);
        if (previous != null) {
          activeSegment.points.add(previous);
        }
        _segments.add(activeSegment);
      }
      activeSegment.points.add(mapped);
      previous = mapped;
    }
  }

  Future<void> _redrawSeededRoute() async {
    if (_disposed || _map == null || _segments.isEmpty) return;
    await _clearRouteLines(clearSegments: false);
    for (final segment in _segments) {
      await _updateSegmentLine(segment);
    }
  }

  Future<void> _enableUserLocation() async {
    final map = _map;
    if (map == null || _disposed) return;
    try {
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: false,
          puckBearingEnabled: true,
        ),
      );
    } catch (_) {
      // Ignore; permission or service may be unavailable.
    }
  }

  Future<void> _moveCameraToUser() async {
    final map = _map;
    if (map == null || _disposed) return;
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      if (_disposed) return;
      map.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (_) {
      try {
        final lastKnown = await geo.Geolocator.getLastKnownPosition();
        if (_disposed) return;
        if (lastKnown == null) return;
        map.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(lastKnown.longitude, lastKnown.latitude),
            ),
            zoom: 14.5,
          ),
          MapAnimationOptions(duration: 1000),
        );
      } catch (_) {
        // Ignore if location isn't available.
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    return perm == geo.LocationPermission.always ||
        perm == geo.LocationPermission.whileInUse;
  }

  Future<void> _startTracking() async {
    if (_tracking || _disposed) return;
    final ok = await _ensureLocationPermission();
    if (!ok || _disposed) return;
    final elapsed = widget.elapsedSeconds ?? 0;
    final isResume =
        (widget.running ?? false) || elapsed > 0 || _hasTrackingData;
    if (!isResume) {
      _resetTrackingState();
      await _clearRouteLines();
    }
    if (_segments.isEmpty) {
      await _startNewSegment(paused: _pausedTracking);
    }
    _tracking = true;
    _positionSub?.cancel();
    final geo.LocationSettings settings;
    if (Platform.isAndroid) {
      settings = geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationTitle: "Cardio session running",
          notificationText: "Tracking your route in the background",
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = geo.AppleSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
      );
    }
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPositionUpdate);
  }

  void _pauseTracking() {
    _tracking = false;
    _positionSub?.cancel();
    _positionSub = null;
  }

  void _finishTracking() {
    _tracking = false;
    _positionSub?.cancel();
    _positionSub = null;
    _resetTrackingState();
    _clearRouteLines();
    if (mounted) setState(() {});
  }

  Future<void> _ensurePolylineManager() async {
    final map = _map;
    if (map == null || _polylineManager != null || _disposed) return;
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
  }

  Future<void> _clearRouteLines({bool clearSegments = true}) async {
    if (_disposed) return;
    if (_polylineManager != null) {
      for (final segment in _segments) {
        final line = segment.line;
        if (line != null) {
          await _polylineManager!.delete(line);
        }
        segment.line = null;
      }
    }
    if (clearSegments) {
      _segments.clear();
    }
  }

  Future<void> _startNewSegment({required bool paused}) async {
    if (_disposed) return;
    await _ensurePolylineManager();
    if (_polylineManager == null) return;
    final segment = _RouteSegment(paused: paused, points: []);
    if (_routePositions.isNotEmpty) {
      segment.points.add(_routePositions.last);
    }
    _segments.add(segment);
  }

  Future<void> _appendRoutePoint(Position point) async {
    if (_disposed) return;
    if (_segments.isEmpty) {
      await _startNewSegment(paused: _pausedTracking);
    }
    if (_segments.isEmpty) return;
    final segment = _segments.last;
    segment.points.add(point);
    await _updateSegmentLine(segment);
  }

  Future<void> _updateSegmentLine(_RouteSegment segment) async {
    if (_disposed) return;
    if (segment.points.length < 2) return;
    await _ensurePolylineManager();
    if (_polylineManager == null) return;
    final lineString = LineString(
      coordinates: List<Position>.from(segment.points),
    );
    final color = segment.paused ? _pausedLineColor : _activeLineColor;
    if (segment.line == null) {
      segment.line = await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: lineString,
          lineColor: color,
          lineOpacity: 0.85,
          lineWidth: 4.5,
          lineJoin: LineJoin.ROUND,
        ),
      );
    } else {
      segment.line!.geometry = lineString;
      await _polylineManager!.update(segment.line!);
    }
  }

  void _onPositionUpdate(geo.Position position) {
    if (_disposed || !_tracking) return;
    if (!widget.trackingEnabled) return;
    final now = DateTime.now();
    if (_ignoreNextDistance) {
      _ignoreNextDistance = false;
      _lastPosition = position;
      _lastPositionTime = now;
      _recentPositions
        ..clear()
        ..add(_TimedPosition(position: position, time: now));
      final routePoint = Position(position.longitude, position.latitude);
      _routePositions.add(routePoint);
      _hasTrackingData = true;
      _appendRoutePoint(routePoint);
      widget.onRoute?.call(_buildRoutePointsPayload());
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final last = _lastPosition;
    if (position.accuracy > 40) {
      return;
    }
    if (position.speedAccuracy > 0 && position.speedAccuracy > 5.0) {
      return;
    }
    if (!_pausedTracking) {
      if (last != null) {
        final segMeters = geo.Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          position.latitude,
          position.longitude,
        );
        final dtMs = _lastPositionTime != null
            ? now.difference(_lastPositionTime!).inMilliseconds
            : 0;
        if (dtMs > 0 && dtMs < 500) {
          return;
        }
        // Ignore tiny GPS jitter to avoid speed spikes/drops
        if (segMeters >= 1.0) {
          _distanceMeters += segMeters;
          _movedMetersSinceStart += segMeters;
        }
      }
      // Compute rolling 10-second speed window from recent positions.
      _recentPositions.add(_TimedPosition(position: position, time: now));
      final cutoff = now.subtract(const Duration(seconds: 10));
      while (_recentPositions.length > 2 &&
          _recentPositions.first.time.isBefore(cutoff)) {
        _recentPositions.removeAt(0);
      }
      double windowMeters = 0;
      if (_recentPositions.length >= 2) {
        for (var i = 1; i < _recentPositions.length; i++) {
          final a = _recentPositions[i - 1].position;
          final b = _recentPositions[i].position;
          windowMeters += geo.Geolocator.distanceBetween(
            a.latitude,
            a.longitude,
            b.latitude,
            b.longitude,
          );
        }
      }
      final windowSeconds = _recentPositions.length >= 2
          ? _recentPositions.last.time
                    .difference(_recentPositions.first.time)
                    .inMilliseconds /
                1000.0
          : 0.0;
      double nextSpeed = (windowSeconds > 0)
          ? (windowMeters / windowSeconds) * 3.6
          : 0.0;
      if (nextSpeed.isNaN || nextSpeed < 0.2) nextSpeed = 0;

      // Avoid non-zero speed before user actually moves a bit
      if (_movedMetersSinceStart < 3.0) {
        nextSpeed = 0;
      }

      // Smooth speed to reduce 0 km/h spikes while walking
      const alpha = 0.2;
      _speedKmh = (_speedKmh * (1 - alpha)) + (nextSpeed * alpha);
    }

    _lastPosition = position;
    _lastPositionTime = now;
    final routePoint = Position(position.longitude, position.latitude);
    _routePositions.add(routePoint);
    _appendRoutePoint(routePoint);
    _hasTrackingData = true;
    if (!_pausedTracking) {
      widget.onMetrics?.call(
        CardioMetrics(distanceMeters: _distanceMeters, speedKmh: _speedKmh),
      );
    }
    widget.onRoute?.call(_buildRoutePointsPayload());
    if (mounted) {
      setState(() {});
    }
  }

  void _resetTrackingState() {
    _distanceMeters = 0;
    _speedKmh = 0;
    _movedMetersSinceStart = 0;
    _routePositions.clear();
    _recentPositions.clear();
    _lastPosition = null;
    _lastPositionTime = null;
    _hasTrackingData = false;
    _pausedTracking = false;
  }

  Future<void> _recenterWithRetry() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await _moveCameraToUser();
    await Future.delayed(const Duration(milliseconds: 800));
    await _moveCameraToUser();
  }

  Widget _mapPlaceholder(String title, String subtitle) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map, color: Colors.white54, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _setPausedTracking(bool paused) {
    if (_pausedTracking == paused) return;
    _pausedTracking = paused;
    if (_tracking) {
      _startNewSegment(paused: paused);
    }
    if (!paused) {
      _ignoreNextDistance = true;
    }
  }

  List<CardioPoint> _buildRoutePointsPayload() {
    if (_segments.isEmpty) {
      return _routePositions
          .map((p) => CardioPoint(lat: p.lat.toDouble(), lng: p.lng.toDouble()))
          .toList();
    }
    final points = <CardioPoint>[];
    for (final segment in _segments) {
      for (final p in segment.points) {
        points.add(
          CardioPoint(
            lat: p.lat.toDouble(),
            lng: p.lng.toDouble(),
            paused: segment.paused,
          ),
        );
      }
    }
    return points;
  }
}

class CardioMetrics {
  final double distanceMeters;
  final double speedKmh;

  const CardioMetrics({required this.distanceMeters, required this.speedKmh});
}

class CardioPoint {
  final double lat;
  final double lng;
  final bool paused;

  const CardioPoint({
    required this.lat,
    required this.lng,
    this.paused = false,
  });
}

class _TimedPosition {
  final geo.Position position;
  final DateTime time;

  const _TimedPosition({required this.position, required this.time});
}

class _RouteSegment {
  _RouteSegment({required this.paused, required this.points});

  final bool paused;
  final List<Position> points;
  PolylineAnnotation? line;
}
