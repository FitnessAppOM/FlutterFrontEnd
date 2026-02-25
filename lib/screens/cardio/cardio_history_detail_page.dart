import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/account_storage.dart';
import '../../services/training/training_service.dart';
import '../../widgets/cardio/cardio_map.dart';
import '../../widgets/cardio/cardio_route_utils.dart';
import '../training/cardio_achievement_sheet.dart';

class CardioHistoryDetailPage extends StatefulWidget {
  const CardioHistoryDetailPage({
    super.key,
    required this.sessionId,
    required this.initialItem,
  });

  final int sessionId;
  final Map<String, dynamic> initialItem;

  @override
  State<CardioHistoryDetailPage> createState() => _CardioHistoryDetailPageState();
}

class _CardioHistoryDetailPageState extends State<CardioHistoryDetailPage> {
  Map<String, dynamic> _item = const {};
  List<CardioPoint> _route = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.initialItem);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId == 0) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = "Please log in to view details.";
        });
        return;
      }
      final detail = await TrainingService.fetchCardioHistoryDetail(
        userId: userId,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _item = detail.isNotEmpty ? detail : _item;
        _route = _parseRoute(detail['route_points']);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load route.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_item['exercise_name'] ?? 'Cardio session').toString();
    final entryDate = _item['entry_date']?.toString();
    final distanceKm = _toDouble(_item['distance_km']);
    final pace = _toDouble(_item['avg_pace_min_km']);
    final duration = _toInt(_item['duration_seconds']);
    final steps = _toInt(_item['steps']);
    final route = _route;

    final snapshotUrl = _buildSnapshotUrl(route);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1014),
        elevation: 0,
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final speedKmh = pace > 0.01 ? 60.0 / pace : 0.0;
              await showModalBottomSheet(
                context: context,
                isDismissible: true,
                enableDrag: true,
                isScrollControlled: true,
                useRootNavigator: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CardioAchievementSheet(
                  durationSeconds: duration,
                  distanceKm: distanceKm,
                  avgSpeedKmh: speedKmh,
                  steps: steps,
                  route: route,
                  userName: null,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text(
            _formatDate(entryDate),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.redAccent,
                  ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _buildMapCard(context, snapshotUrl, route.isNotEmpty),
          const SizedBox(height: 18),
          _buildMetricsRow(
            context,
            label: "Distance",
            value: _formatDistance(distanceKm),
          ),
          const SizedBox(height: 10),
          _buildMetricsRow(
            context,
            label: "Pace",
            value: _formatPace(pace),
          ),
          const SizedBox(height: 10),
          _buildMetricsRow(
            context,
            label: "Duration",
            value: _formatDuration(duration),
          ),
          if (steps > 0) ...[
            const SizedBox(height: 10),
            _buildMetricsRow(
              context,
              label: "Steps",
              value: steps.toString(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, String url, bool hasRoute) {
    if (!hasRoute || url.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Text(
            "Route not available",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Colors.white.withOpacity(0.05),
              child: Center(
                child: Text(
                  "Map unavailable",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricsRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  String _buildSnapshotUrl(List<CardioPoint> route) {
    final token = dotenv.maybeGet('MAPBOX_PUBLIC_KEY') ?? '';
    return buildCardioSnapshotUrl(
      token: token,
      route: route,
      width: 900,
      height: 540,
      padding: 70,
    );
  }

  List<CardioPoint> _parseRoute(dynamic raw) {
    if (raw is! List) return const [];
    final List<CardioPoint> points = [];
    for (final item in raw) {
      if (item is Map) {
        final lat = _toDouble(item['lat']);
        final lng = _toDouble(item['lng']);
        if (lat != 0 && lng != 0) {
          points.add(CardioPoint(lat: lat, lng: lng));
        }
      }
    }
    return points;
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return "--";
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      final m = months[d.month - 1];
      return "$m ${d.day}";
    } catch (_) {
      return isoDate;
    }
  }

  String _formatDistance(double km) {
    if (km <= 0) return "0.00 km";
    return "${km.toStringAsFixed(2)} km";
  }

  String _formatPace(double paceMinKm) {
    if (paceMinKm <= 0.01) return "--:-- /km";
    final minutes = paceMinKm.floor();
    final seconds = ((paceMinKm - minutes) * 60).round().clamp(0, 59);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return "$mm:$ss /km";
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return "00:00";
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

 
