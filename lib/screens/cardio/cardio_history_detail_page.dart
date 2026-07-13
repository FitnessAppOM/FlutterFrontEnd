import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:taqaproject/TaqaUI/components/taqa_back_button.dart';
import 'package:taqaproject/TaqaUI/components/taqa_page_app_bar.dart';
import 'package:taqaproject/TaqaUI/components/taqa_pillar_card.dart';
import 'package:taqaproject/TaqaUI/Typography/taqa_ui_typography.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';
import 'package:taqaproject/theme/app_theme.dart';

import '../../core/account_storage.dart';
import '../../services/training/training_service.dart';
import '../../widgets/cardio/cardio_map.dart';
import '../../widgets/cardio/cardio_exercise_utils.dart';
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
  State<CardioHistoryDetailPage> createState() =>
      _CardioHistoryDetailPageState();
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
    final inclinePercent = _toDouble(_item['incline_percent']);
    final route = _route;
    final showDistance = !isIndoorCardioExerciseName(name);
    final showIncline = isTreadmillExerciseName(name) && inclinePercent > 0;
    final isMapless = isIndoorCardioExerciseName(name);

    final snapshotUrl = _buildSnapshotUrl(route: route);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        title: name,
        backgroundColor: AppColors.appBackground,
        titleColor: TaqaUiColors.charcoal,
        leading: const TaqaBackButton(color: TaqaUiColors.charcoal),
        trailing: IconButton(
          icon: const Icon(Icons.ios_share, color: TaqaUiColors.charcoal),
          onPressed: () async {
            final speedKmh = pace > 0.01 ? 60.0 / pace : 0.0;
            final sessionDate = _parseDate(entryDate);
            final userName = await AccountStorage.getName();
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
                exerciseName: name,
                userName: userName,
                snapshotUrl: snapshotUrl,
                sessionDate: sessionDate,
                inclinePercent: inclinePercent,
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Text(
              _formatDate(entryDate),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(13),
                color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else if (!isMapless)
              _buildMapCard(context, snapshotUrl, route.isNotEmpty),
            if (_loading || !isMapless) const SizedBox(height: 18),
            if (showDistance) ...[
              TaqaPillarCard(
                metricKey: 'cardio_distance',
                label: 'Distance',
                score: distanceKm,
                maxScore: 10,
                icon: Icons.route_rounded,
                color: const Color(0xFF35B6FF),
                details: const {},
                detailLabels: const {},
                valueDisplay: _formatDistance(distanceKm),
              ),
              SizedBox(height: TaqaUiScale.h(12)),
            ],
            TaqaPillarCard(
              metricKey: 'cardio_pace',
              label: 'Pace',
              score: pace,
              maxScore: 10,
              icon: Icons.speed_rounded,
              color: const Color(0xFF9B8CFF),
              details: const {},
              detailLabels: const {},
              valueDisplay: _formatPace(pace),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaPillarCard(
              metricKey: 'cardio_duration',
              label: 'Duration',
              score: duration / 60.0,
              maxScore: 90,
              icon: Icons.timer_rounded,
              color: const Color(0xFFE84C4F),
              details: const {},
              detailLabels: const {},
              valueDisplay: _formatDuration(duration),
            ),
            if (steps > 0) ...[
              SizedBox(height: TaqaUiScale.h(12)),
              TaqaPillarCard(
                metricKey: 'cardio_steps',
                label: 'Steps',
                score: steps.toDouble(),
                maxScore: 10000,
                icon: Icons.directions_walk_rounded,
                color: const Color(0xFFFF8A00),
                details: const {},
                detailLabels: const {},
                valueDisplay: steps.toString(),
              ),
            ],
            if (showIncline) ...[
              SizedBox(height: TaqaUiScale.h(12)),
              TaqaPillarCard(
                metricKey: 'cardio_incline',
                label: 'Incline',
                score: inclinePercent,
                maxScore: 20,
                icon: Icons.terrain_rounded,
                color: const Color(0xFF6BBE45),
                details: const {},
                detailLabels: const {},
                valueDisplay: "${inclinePercent.toStringAsFixed(1)}%",
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, String url, bool hasRoute) {
    if (!hasRoute || url.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: TaqaUiColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: TaqaUiColors.charcoal.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            "Route not available",
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRect(
          child: Transform.scale(
            scale: 1.5,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: TaqaUiColors.white,
                  child: Center(
                    child: Text(
                      "Map unavailable",
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _buildSnapshotUrl({required List<CardioPoint> route}) {
    final token = dotenv.maybeGet('MAPBOX_PUBLIC_KEY') ?? '';
    return buildCardioSnapshotUrlMaster(token: token, route: route);
  }

  List<CardioPoint> _parseRoute(dynamic raw) {
    if (raw is! List) return const [];
    final List<CardioPoint> points = [];
    for (final item in raw) {
      if (item is Map && item['points'] is List) {
        final paused = item['paused'] == true;
        final segPoints = item['points'] as List;
        for (final p in segPoints) {
          if (p is Map) {
            final lat = _toDouble(p['lat']);
            final lng = _toDouble(p['lng']);
            if (lat != 0 && lng != 0) {
              points.add(CardioPoint(lat: lat, lng: lng, paused: paused));
            }
          }
        }
        continue;
      }
      if (item is Map) {
        final lat = _toDouble(item['lat']);
        final lng = _toDouble(item['lng']);
        final paused = item['paused'] == true;
        if (lat != 0 && lng != 0) {
          points.add(CardioPoint(lat: lat, lng: lng, paused: paused));
        }
      }
    }
    return points;
  }

  DateTime? _parseDate(String? isoDate) {
    if (isoDate == null || isoDate.trim().isEmpty) return null;
    try {
      return DateTime.parse(isoDate);
    } catch (_) {
      return null;
    }
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
