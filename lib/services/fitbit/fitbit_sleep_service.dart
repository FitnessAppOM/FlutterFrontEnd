import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

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
  final List<FitbitSleepLog> logs;

  const FitbitSleepSummary({
    required this.totalMinutesAsleep,
    required this.totalTimeInBed,
    required this.sleepGoalMinutes,
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

  Future<FitbitSleepSummary?> fetchSummary(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final url = Uri.parse("${ApiConfig.baseUrl}/fitbit/sleep?user_id=$userId&date=$dateStr");
    final res = await http.get(url);
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
    for (final item in logsRaw) {
      if (item is! Map) continue;
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

    return FitbitSleepSummary(
      totalMinutesAsleep: _int(summary["totalMinutesAsleep"]),
      totalTimeInBed: _int(summary["totalTimeInBed"]),
      sleepGoalMinutes: _int(goals["minDuration"]),
      logs: logs,
    );
  }
}
