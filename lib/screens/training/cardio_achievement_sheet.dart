import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/share/cardio_share_service.dart';

import '../../widgets/cardio/cardio_map.dart';

class CardioAchievementSheet extends StatefulWidget {
  const CardioAchievementSheet({
    super.key,
    required this.durationSeconds,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.steps,
    required this.route,
    this.userName,
  });

  final int durationSeconds;
  final double distanceKm;
  final double avgSpeedKmh;
  final int steps;
  final List<CardioPoint> route;
  final String? userName;

  @override
  State<CardioAchievementSheet> createState() => _CardioAchievementSheetState();
}

class _CardioAchievementSheetState extends State<CardioAchievementSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _saving = false;
  bool _snapshotReady = false;
  bool _sharing = false;
  bool _hideMapForCapture = false;

  String _formatTime(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  String _paceLabel(double speedKmh) {
    if (speedKmh <= 0.1) return "--:-- /km";
    final paceMin = 60.0 / speedKmh;
    final paceMinutes = paceMin.floor();
    final paceSeconds = ((paceMin - paceMinutes) * 60).round().clamp(0, 59);
    return "${paceMinutes.toString().padLeft(2, '0')}:${paceSeconds.toString().padLeft(2, '0')} /km";
  }

  String _buildSnapshotUrl() {
    final token = dotenv.maybeGet('MAPBOX_PUBLIC_KEY') ?? '';
    if (token.isEmpty || widget.route.isEmpty) return '';
    final encoded = _encodePolyline(widget.route);
    final path = Uri.encodeComponent('path-5+2D7CFF-0.85($encoded)');
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'
        '$path/auto/800x480?access_token=$token';
  }

  Future<void> _saveScreenshot() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await CardioShareService.ensurePhotoPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo permission denied')),
          );
        }
        return;
      }
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final output = await _buildExportBytes(boundary);
      if (output == null) return;
      await CardioShareService.savePngBytes(output);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Photos')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List?> _capturePng(RenderRepaintBoundary boundary) {
    return CardioShareService.capturePng(boundary);
  }

  Future<Uint8List?> _buildExportBytes(RenderRepaintBoundary boundary) async {
    final bytes = await _capturePngWithOptionalHideMap(boundary);
    if (bytes == null) return null;
    final flattened = await CardioShareService.flattenPngOnBackground(
      bytes,
      const Color(0xFF0B0F1A),
      cornerRadius: 22,
    );
    return flattened ?? bytes;
  }

  Future<Uint8List?> _capturePngWithOptionalHideMap(
    RenderRepaintBoundary boundary,
  ) async {
    final snapshotUrl = _buildSnapshotUrl();
    final shouldHideMap = snapshotUrl.isEmpty;
    if (!shouldHideMap) {
      return _capturePng(boundary);
    }
    if (mounted) {
      setState(() => _hideMapForCapture = true);
    }
    await _nextFrame();
    final bytes = await _capturePng(boundary);
    if (mounted) {
      setState(() => _hideMapForCapture = false);
    }
    return bytes;
  }

  Future<void> _nextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }


  Future<void> _shareScreenshot() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final output = await _buildExportBytes(boundary);
      if (output == null) return;
      await CardioShareService.sharePngBytes(context, output);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotUrl = _buildSnapshotUrl();
    if (snapshotUrl.isEmpty && !_snapshotReady) {
      _snapshotReady = true;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0B0F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            RepaintBoundary(
              key: _captureKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: const Color(0xFF0B0F1A),
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0E1A33), Color(0xFF0B0F1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
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
                                        'TaqaFitness',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                      ),
                                      Text(
                                        widget.userName != null && widget.userName!.trim().isNotEmpty
                                            ? widget.userName!
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
                                    DateTime.now().toLocal().toString().split(' ').first,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                      if (!_hideMapForCapture) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: snapshotUrl.isEmpty
                              ? Container(
                                  height: 220,
                                  color: Colors.white12,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Route unavailable',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : Image.network(
                                  snapshotUrl,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) {
                                      if (!_snapshotReady) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) setState(() => _snapshotReady = true);
                                        });
                                      }
                                      return child;
                                    }
                                    return Container(
                                      height: 220,
                                      color: Colors.white10,
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_hideMapForCapture) const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricChip(
                              label: 'Time',
                              value: _formatTime(widget.durationSeconds),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricChip(
                              label: 'Distance',
                              value: '${widget.distanceKm.toStringAsFixed(2)} km',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricChip(
                              label: 'Pace',
                              value: _paceLabel(widget.avgSpeedKmh),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricChip(
                              label: 'Steps',
                              value: '${widget.steps}',
                            ),
                          ),
                        ],
                      ),
                        ],
                    ),
                  ),
                ),
              ),
            ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_saving || !_snapshotReady) ? null : _saveScreenshot,
                child: Text(_saving ? 'Saving...' : _snapshotReady ? 'Save to Photos' : 'Preparing...'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: (_sharing || !_snapshotReady) ? null : _shareScreenshot,
                child: Text(_sharing ? 'Sharing...' : _snapshotReady ? 'Share' : 'Preparing...'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _encodePolyline(List<CardioPoint> points) {
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
