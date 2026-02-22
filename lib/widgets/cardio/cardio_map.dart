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
  });

  final bool hasToken;
  final bool expanded;
  final double? height;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onFinish;

  @override
  State<CardioMap> createState() => _CardioMapState();
}

class _CardioMapState extends State<CardioMap> {
  MapboxMap? _map;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
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
              onStart: widget.onStart,
              onPause: widget.onPause,
              onFinish: widget.onFinish,
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
          showAccuracyRing: true,
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
