import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../core/daily_provider_push_service.dart';
import 'fitbit_db_service.dart';

class FitbitSleepLog {
  final DateTime? start;
  final DateTime? end;
  final int? minutesAsleep;
  final int? timeInBed;
  final int? efficiency;
  final bool? isMainSleep;
  final Map<String, dynamic>? levels;

  const FitbitSleepLog({
    required this.start,
    required this.end,
    required this.minutesAsleep,
    required this.timeInBed,
    required this.efficiency,
    required this.isMainSleep,
    required this.levels,
  });
}

class FitbitSleepSummary {
  final int? totalMinutesAsleep;
  final int? totalTimeInBed;
  final int? sleepGoalMinutes;
  final int? sleepScore;
  final Map<String, int> stageMinutes;
  final List<FitbitSleepLog> logs;

  const FitbitSleepSummary({
    required this.totalMinutesAsleep,
    required this.totalTimeInBed,
    required this.sleepGoalMinutes,
    required this.sleepScore,
    required this.stageMinutes,
    required this.logs,
  });
}

class FitbitSleepService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  bool _isToday(DateTime date) {
    // Treat the dashboard's push-clock "today" as live; see
    // DailyProviderPushService.isInProgressDay.
    return DailyProviderPushService.isInProgressDay(date);
  }

  Map<String, int> _parseStageMinutes(dynamic raw) {
    int? _int(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    if (raw is String) {
      try {
        return _parseStageMinutes(jsonDecode(raw));
      } catch (_) {
        return const {};
      }
    }
    if (raw is! Map) return const {};

    final fromSummary = raw["summary"];
    final fromStages = raw["stages"];
    final source = fromSummary is Map
        ? fromSummary
        : (fromStages is Map ? fromStages : raw);
    final out = <String, int>{};
    source.forEach((k, v) {
      if (k is! String) return;
      final minutes = v is Map ? _int(v["minutes"]) : _int(v);
      if (minutes == null || minutes <= 0) return;
      out[k] = minutes;
    });
    return out;
  }

  Future<FitbitSleepSummary?> fetchSummary(DateTime date) async {
    if (!_isToday(date)) {
      final row = await FitbitDailyMetricsDbService().fetchRow(date);
      if (row == null) return null;
      int? _int(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }

      final minutesAsleep = _int(row["sleep_minutes_asleep"]);
      final timeInBed = _int(row["sleep_time_in_bed"]);
      final stageMinutes = _parseStageMinutes(row["sleep_stages_json"]);
      final sleepScore = _int(row["sleep_score"]);
      if (minutesAsleep == null &&
          timeInBed == null &&
          sleepScore == null &&
          stageMinutes.isEmpty) {
        return null;
      }
      return FitbitSleepSummary(
        totalMinutesAsleep: minutesAsleep,
        totalTimeInBed: timeInBed,
        sleepGoalMinutes: null,
        sleepScore: sleepScore,
        stageMinutes: stageMinutes,
        logs: const [],
      );
    }
    return _fetchFromApi(date);
  }

  Future<FitbitSleepSummary?> _fetchFromApi(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/sleep?user_id=$userId&date=$dateStr",
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception("Failed to load Fitbit sleep");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final summary = data["summary"] is Map<String, dynamic>
        ? data["summary"] as Map<String, dynamic>
        : <String, dynamic>{};
    final goals = data["goals"] is Map<String, dynamic>
        ? data["goals"] as Map<String, dynamic>
        : <String, dynamic>{};
    final logsRaw = data["sleep"] is List ? data["sleep"] as List : const [];

    int? _int(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    DateTime? _dt(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final logs = <FitbitSleepLog>[];
    Map<String, int> stageMinutes = _parseStageMinutes(summary["stages"]);
    for (final item in logsRaw) {
      if (item is! Map) continue;
      if (stageMinutes.isEmpty && item["isMainSleep"] == true) {
        stageMinutes = _parseStageMinutes(item["levels"]);
      }
      logs.add(
        FitbitSleepLog(
          start: _dt(item["startTime"]),
          end: _dt(item["endTime"]),
          minutesAsleep: _int(item["minutesAsleep"]),
          timeInBed: _int(item["timeInBed"]),
          efficiency: _int(item["efficiency"]),
          isMainSleep: item["isMainSleep"] == true,
          levels: item["levels"] is Map<String, dynamic>
              ? item["levels"] as Map<String, dynamic>
              : null,
        ),
      );
    }
    if (stageMinutes.isEmpty && logsRaw.isNotEmpty && logsRaw.first is Map) {
      stageMinutes = _parseStageMinutes((logsRaw.first as Map)["levels"]);
    }

    return FitbitSleepSummary(
      totalMinutesAsleep: _int(summary["totalMinutesAsleep"]),
      totalTimeInBed: _int(summary["totalTimeInBed"]),
      sleepGoalMinutes: _int(goals["minDuration"]),
      sleepScore: _int(
        summary["sleepScore"] ??
            summary["sleep_score"] ??
            data["sleepScore"] ??
            data["sleep_score"],
      ),
      stageMinutes: stageMinutes,
      logs: logs,
    );
  }
}
