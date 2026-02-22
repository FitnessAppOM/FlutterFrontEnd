import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../theme/app_theme.dart';
import 'cardio_map_controls.dart';

class CardioMap extends StatefulWidget {
  const CardioMap({
    super.key,
    required this.hasToken,
    required this.expanded,
    this.height,
    this.onStart,
    this.onPause,
    this.onFinish,
    this.onMetrics,
    this.onRoute,
    this.steps,
  });

  final bool hasToken;
  final bool expanded;
  final double? height;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onFinish;
  final ValueChanged<CardioMetrics>? onMetrics;
  final ValueChanged<List<CardioPoint>>? onRoute;
  final int? steps;

  @override
  State<CardioMap> createState() => _CardioMapState();
}

class _CardioMapState extends State<CardioMap> {
  MapboxMap? _map;
  bool _disposed = false;
  StreamSubscription<geo.Position>? _positionSub;
  PolylineAnnotationManager? _polylineManager;
  PolylineAnnotation? _routeLine;
  final List<Position> _routePositions = [];
  geo.Position? _lastPosition;
  DateTime? _lastPositionTime;
  double _distanceMeters = 0;
  double _speedKmh = 0;
  bool _tracking = false;
  double _movedMetersSinceStart = 0;

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CardioMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) {
      _recenterWithRetry();
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
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(2.3522, 48.8566)),
              zoom: 11.5,
            ),
            onMapCreated: (mapboxMap) {
              _map = mapboxMap;
              _enableUserLocation();
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
              onStart: () {
                _startTracking();
                widget.onStart?.call();
              },
              onPause: () {
                _pauseTracking();
                widget.onPause?.call();
              },
              onFinish: () {
                widget.onFinish?.call();
                _finishTracking();
              },
            ),
          ),
        ],
      ),
    );
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
    _distanceMeters = 0;
    _speedKmh = 0;
    _movedMetersSinceStart = 0;
    _routePositions.clear();
    _lastPosition = null;
    await _clearRouteLine();
    _tracking = true;
    _positionSub?.cancel();
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
      ),
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
    _clearRouteLine();
    if (mounted) setState(() {});
  }

  Future<void> _ensurePolylineManager() async {
    final map = _map;
    if (map == null || _polylineManager != null || _disposed) return;
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
  }

  Future<void> _clearRouteLine() async {
    if (_polylineManager != null && _routeLine != null) {
      await _polylineManager!.delete(_routeLine!);
      _routeLine = null;
    }
  }

  Future<void> _updateRouteLine() async {
    if (_disposed) return;
    if (_routePositions.length < 2) return;
    await _ensurePolylineManager();
    if (_polylineManager == null) return;
    final lineString = LineString(coordinates: List<Position>.from(_routePositions));
    if (_routeLine == null) {
      _routeLine = await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: lineString,
          lineColor: const Color(0xFF2D7CFF).value,
          lineOpacity: 0.85,
          lineWidth: 4.5,
          lineJoin: LineJoin.ROUND,
        ),
      );
    } else {
      _routeLine!.geometry = lineString;
      await _polylineManager!.update(_routeLine!);
    }
  }

  void _onPositionUpdate(geo.Position position) {
    if (_disposed || !_tracking) return;
    final now = DateTime.now();
    final last = _lastPosition;
    if (last != null) {
      final segMeters = geo.Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      // Ignore tiny GPS jitter to avoid speed spikes/drops
      if (segMeters >= 1.0) {
        _distanceMeters += segMeters;
        _movedMetersSinceStart += segMeters;
      }
    }
    // Compute speed: prefer sensor speed if reliable, otherwise derive from distance/time
    final double sensorSpeedKmh =
        position.speed >= 0 ? position.speed * 3.6 : 0.0;
    final bool sensorReliable = position.speedAccuracy > 0
        ? position.speedAccuracy <= 2.5
        : position.accuracy <= 15;
    double derivedSpeedKmh = 0;
    if (last != null && _lastPositionTime != null) {
      final dt = now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
      if (dt >= 1.2 && position.accuracy <= 25) {
        final segMeters = geo.Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          position.latitude,
          position.longitude,
        );
        derivedSpeedKmh = (segMeters / dt) * 3.6;
      }
    }
    double nextSpeed = 0;
    if (sensorReliable && sensorSpeedKmh >= 0.5) {
      nextSpeed = sensorSpeedKmh;
    } else {
      nextSpeed = derivedSpeedKmh;
    }
    // Drop spikes when GPS accuracy is poor or movement is implausible
    if (position.accuracy > 25 && nextSpeed > 6) {
      nextSpeed = 0;
    }
    if (_lastPositionTime != null) {
      final dt = now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
      if (dt > 0 && _lastPosition != null) {
        final segMeters = geo.Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (segMeters > 20 && dt < 2.0) {
          // Large jump in short time -> GPS glitch
          nextSpeed = 0;
        }
      }
    }
    if (nextSpeed.isNaN || nextSpeed < 0.2) nextSpeed = 0;

    // Avoid non-zero speed before user actually moves a bit
    if (_movedMetersSinceStart < 3.0) {
      nextSpeed = 0;
    }

    // Smooth speed to reduce 0 km/h spikes while walking
    const alpha = 0.2;
    _speedKmh = (_speedKmh * (1 - alpha)) + (nextSpeed * alpha);

    _lastPosition = position;
    _lastPositionTime = now;
    _routePositions.add(Position(position.longitude, position.latitude));
    _updateRouteLine();
    widget.onMetrics?.call(
      CardioMetrics(distanceMeters: _distanceMeters, speedKmh: _speedKmh),
    );
    widget.onRoute?.call(_routePositions
        .map((p) => CardioPoint(lat: p.lat.toDouble(), lng: p.lng.toDouble()))
        .toList());
    if (mounted) {
      setState(() {});
    }
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
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
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
}

class CardioMetrics {
  final double distanceMeters;
  final double speedKmh;

  const CardioMetrics({
    required this.distanceMeters,
    required this.speedKmh,
  });
}

class CardioPoint {
  final double lat;
  final double lng;

  const CardioPoint({required this.lat, required this.lng});
}
