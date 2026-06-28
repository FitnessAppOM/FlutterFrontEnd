import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taqaproject/TaqaUI/Typography/taqa_ui_typography.dart';
import 'package:taqaproject/TaqaUI/components/taqa_log_entry_card.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';

import '../../core/account_storage.dart';
import '../../services/health/workout_health_sync_service.dart';
import '../../services/training/training_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/cardio/cardio_exercise_utils.dart';
import 'cardio_history_detail_page.dart';

class CardioHistoryPage extends StatefulWidget {
  const CardioHistoryPage({super.key});

  @override
  State<CardioHistoryPage> createState() => _CardioHistoryPageState();
}

class _CardioHistoryPageState extends State<CardioHistoryPage> {
  bool _loading = true;
  bool _backfillingHealth = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  String _titleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length <= 4 && word == word.toUpperCase()) return word;
          final lower = word.toLowerCase();
          return "${lower[0].toUpperCase()}${lower.substring(1)}";
        })
        .join(' ');
  }

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
      final items = await TrainingService.fetchCardioHistory(
        userId: userId,
        limit: 100,
      );
      final filtered = items
          .where((e) => _toDouble(e['distance_km']) >= 0.1)
          .toList();
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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pushAllCardioHistoryToAppleHealth() async {
    if (_backfillingHealth) return;
    if (!Platform.isIOS) {
      if (!mounted) return;
      AppToast.show(
        context,
        "This history push is for Apple Health on iOS.",
        type: AppToastType.info,
      );
      return;
    }

    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) {
      if (!mounted) return;
      AppToast.show(context, "Please log in first.", type: AppToastType.info);
      return;
    }

    setState(() {
      _backfillingHealth = true;
    });

    try {
      // Fetch a larger batch than UI display so testing can include more sessions.
      final all = await TrainingService.fetchCardioHistory(
        userId: userId,
        limit: 1000,
      );
      if (all.isEmpty) {
        if (!mounted) return;
        AppToast.show(
          context,
          "No cardio sessions found to push.",
          type: AppToastType.info,
        );
        return;
      }
      final result = await WorkoutHealthSyncService()
          .writeCardioHistorySessions(sessions: all);
      if (!mounted) return;
      final total = result['total'] ?? 0;
      final written = result['written'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      final failed = result['failed'] ?? 0;
      late final String message;
      AppToastType toastType = AppToastType.info;
      if (written > 0 && skipped == 0 && failed == 0) {
        message =
            "Apple Health backfill done: pushed $written/$total sessions.";
        toastType = AppToastType.success;
      } else if (written == 0 && skipped > 0 && failed == 0) {
        message =
            "Apple Health backfill done: all $skipped/$total sessions were already in Health.";
        toastType = AppToastType.info;
      } else if (written > 0 && failed == 0) {
        message =
            "Apple Health backfill done: pushed $written new, skipped $skipped already in Health.";
        toastType = AppToastType.success;
      } else {
        message =
            "Apple Health backfill finished: pushed $written, skipped $skipped, failed $failed.";
        toastType = AppToastType.info;
      }
      AppToast.show(context, message, type: toastType);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        "Failed to push cardio history to Apple Health.",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _backfillingHealth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: AppBar(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        centerTitle: true,
        elevation: 0,
        title: Text(
          "Cardio History",
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 2.5,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: TaqaUiScale.insetsLTRB(16, 19, 16, 24),
          children: [
            Text(
              "Completed Cardio Sessions",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(25),
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(25)),
            if (_loading)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(24)),
                  child: CircularProgressIndicator(
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w400,
                  height: 21 / 15,
                  letterSpacing: 0,
                  color: Colors.redAccent,
                ),
              )
            else if (_items.isEmpty)
              Text(
                "No cardio sessions yet.",
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w400,
                  height: 21 / 15,
                  letterSpacing: 0,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              )
            else
              ..._items.map((item) => _buildHistoryItem(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> item) {
    final name = _titleCase(
      (item['exercise_name'] ?? 'Cardio Session').toString(),
    );
    final entryDate = item['entry_date']?.toString();
    final distanceKm = _toDouble(item['distance_km']);
    final pace = _toDouble(item['avg_pace_min_km']);
    final duration = _toInt(item['duration_seconds']);
    final steps = _toInt(item['steps']);
    final inclinePercent = _toDouble(item['incline_percent']);
    final showDistance = !isIndoorCardioExerciseName(name);
    final showIncline = isTreadmillExerciseName(name) && inclinePercent > 0;
    final sessionId = _toInt(item['id']);

    final label = [
      if (showDistance) _formatDistance(distanceKm),
      _formatPace(pace),
      _formatDuration(duration),
      if (steps > 0) "$steps steps",
      if (showIncline) "${inclinePercent.toStringAsFixed(1)}% incline",
    ].join(" • ");

    return TaqaLogEntryCard(
      title: name,
      badgeText: _formatDate(entryDate).toUpperCase(),
      subtitle: _titleCase(label),
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
