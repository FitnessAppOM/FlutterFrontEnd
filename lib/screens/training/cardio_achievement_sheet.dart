import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

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

  String _formatTime(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  String _buildSnapshotUrl() {
    final token = dotenv.maybeGet('MAPBOX_PUBLIC_KEY') ?? '';
    if (token.isEmpty || widget.route.isEmpty) return '';
    final encoded = _encodePolyline(widget.route);
    final path = Uri.encodeComponent('path-5+2D7CFF-0.85($encoded)');
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'
        '$path/auto/800x480?access_token=$token';
  }

  Future<bool> _ensurePhotoPermission() async {
    final photos = await Permission.photos.request();
    if (photos.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> _saveScreenshot() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await _ensurePhotoPermission();
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
      final bytes = await _capturePng(boundary);
      if (bytes == null) return;
      await ImageGallerySaver.saveImage(bytes, quality: 100, name: 'cardio_achievement');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Photos')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List?> _capturePng(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareScreenshot() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final bytes = await _capturePng(boundary);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/cardio_achievement.png';
      final file = await File(filePath).writeAsBytes(bytes, flush: true);
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? Rect.fromLTWH(0, 0, 1, 1)
          : box.localToGlobal(Offset.zero) & box.size;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Hey! Check out my latest cardio session on TaqaFitness.',
        sharePositionOrigin: origin,
      );
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MetricChip(label: 'Time', value: _formatTime(widget.durationSeconds)),
                          _MetricChip(label: 'Distance', value: '${widget.distanceKm.toStringAsFixed(2)} km'),
                          _MetricChip(label: 'Speed', value: '${widget.avgSpeedKmh.toStringAsFixed(1)} km/h'),
                          _MetricChip(label: 'Steps', value: '${widget.steps}'),
                        ],
                      ),
                    ],
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
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
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
