import 'package:flutter/material.dart';

import '../../core/account_storage.dart';
import '../../services/training/training_service.dart';
import 'cardio_history_detail_page.dart';

class CardioHistoryPage extends StatefulWidget {
  const CardioHistoryPage({super.key});

  @override
  State<CardioHistoryPage> createState() => _CardioHistoryPageState();
}

class _CardioHistoryPageState extends State<CardioHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Please log in to view cardio history.";
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await TrainingService.fetchCardioHistory(userId: userId, limit: 100);
      final filtered = items.where((e) => _toDouble(e['distance_km']) >= 0.1).toList();
      if (!mounted) return;
      setState(() {
        _items = filtered;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load cardio history.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1014),
        elevation: 0,
        title: const Text("Cardio history"),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Text(
              "Your latest sessions",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                    ),
              )
            else if (_items.isEmpty)
              Text(
                "No cardio sessions yet.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
              )
            else
              ..._items.map((item) {
                final sessionId = _toInt(item['id']);
                return InkWell(
                  onTap: () {
                    if (sessionId <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't open this session.")),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CardioHistoryDetailPage(
                          sessionId: sessionId,
                          initialItem: item,
                        ),
                      ),
                    );
                  },
                  child: _buildHistoryItem(item),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final name = (item['exercise_name'] ?? 'Cardio session').toString();
    final entryDate = item['entry_date']?.toString();
    final distanceKm = _toDouble(item['distance_km']);
    final pace = _toDouble(item['avg_pace_min_km']);
    final duration = _toInt(item['duration_seconds']);
    final steps = _toInt(item['steps']);

    final label = [
      _formatDistance(distanceKm),
      _formatPace(pace),
      _formatDuration(duration),
      if (steps > 0) "$steps steps",
    ].join(" • ");

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDate(entryDate),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
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
