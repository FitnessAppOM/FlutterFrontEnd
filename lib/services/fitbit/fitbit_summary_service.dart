import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'fitbit_db_service.dart';
import 'fitbit_activity_service.dart';
import 'fitbit_heart_service.dart';
import 'fitbit_sleep_service.dart';
import 'fitbit_vitals_service.dart';
import 'fitbit_body_service.dart';

class FitbitSummaryBundle {
  final FitbitActivitySummary? activity;
  final FitbitHeartSummary? heart;
  final FitbitSleepSummary? sleep;
  final FitbitVitalsSummary? vitals;
  final FitbitBodySummary? body;

  const FitbitSummaryBundle({
    required this.activity,
    required this.heart,
    required this.sleep,
    required this.vitals,
    required this.body,
  });
}

class FitbitSummaryService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<FitbitSummaryBundle?> fetchSummary(DateTime date) async {
    if (!_isToday(date)) {
      return _fetchSummaryFromDb(date);
    }
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final headers = await AccountStorage.getAuthHeaders();
    final url = Uri.parse("${ApiConfig.baseUrl}/fitbit/summary?user_id=$userId&date=$dateStr");

    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception("Fitbit summary failed: ${res.body}");
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return null;

    FitbitActivitySummary? activity;
    final activityNode = data["activity"];
    if (activityNode is Map<String, dynamic>) {
      final summary = activityNode["summary"] is Map<String, dynamic>
          ? activityNode["summary"] as Map<String, dynamic>
          : <String, dynamic>{};
      final goals = activityNode["goals"] is Map<String, dynamic>
          ? activityNode["goals"] as Map<String, dynamic>
          : <String, dynamic>{};
      int? _int(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }

      double? _double(dynamic v) {
        if (v == null) return null;
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      activity = FitbitActivitySummary(
        steps: _int(summary["steps"]),
        distance: _double(summary["distance"]),
        calories: _int(summary["calories"]),
        floors: _int(summary["floors"]),
        activeMinutes: _int(summary["active_minutes"]),
        goalSteps: _int(goals["steps"]),
        goalDistance: _double(goals["distance"]),
        goalCalories: _int(goals["calories"]),
        goalFloors: _int(goals["floors"]),
        goalActiveMinutes: _int(goals["active_minutes"]),
      );
    }

    FitbitSleepSummary? sleep;
    final sleepNode = data["sleep"];
    if (sleepNode is Map<String, dynamic>) {
      final summary = sleepNode["summary"] is Map<String, dynamic>
          ? sleepNode["summary"] as Map<String, dynamic>
          : <String, dynamic>{};
      final goals = sleepNode["goals"] is Map<String, dynamic>
          ? sleepNode["goals"] as Map<String, dynamic>
          : <String, dynamic>{};
      final logsRaw = sleepNode["sleep"] is List ? sleepNode["sleep"] as List : const [];

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

      sleep = FitbitSleepSummary(
        totalMinutesAsleep: _int(summary["totalMinutesAsleep"]),
        totalTimeInBed: _int(summary["totalTimeInBed"]),
        sleepGoalMinutes: _int(goals["minDuration"]),
        logs: logs,
      );
    }

    FitbitHeartSummary? heart;
    final heartNode = data["heart"];
    final hrvNode = data["hrv"];
    final cardioNode = data["cardio"];
    if (heartNode is Map<String, dynamic> ||
        hrvNode is Map<String, dynamic> ||
        cardioNode is Map<String, dynamic>) {
      int? _int(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }

      double? _double(dynamic v) {
        if (v == null) return null;
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      final zones = heartNode is Map<String, dynamic> && heartNode["zones"] is List
          ? heartNode["zones"] as List
          : const [];
      final vo2 = cardioNode is Map<String, dynamic> ? cardioNode["vo2max"]?.toString() : null;

      heart = FitbitHeartSummary(
        restingHr: _int(heartNode is Map<String, dynamic> ? heartNode["resting_hr"] : null),
        hrvRmssd: _double(hrvNode is Map<String, dynamic> ? hrvNode["daily_rmssd"] : null),
        vo2Max: vo2,
        zones: zones,
      );
    }

    FitbitVitalsSummary? vitals;
    final vitalsNode = data["vitals"];
    if (vitalsNode is Map<String, dynamic>) {
      final spo2 = vitalsNode["spo2"] is Map<String, dynamic>
          ? vitalsNode["spo2"] as Map<String, dynamic>
          : null;
      final temp = vitalsNode["temperature"] is Map<String, dynamic>
          ? vitalsNode["temperature"] as Map<String, dynamic>
          : null;
      final breathing = vitalsNode["breathing"] is Map<String, dynamic>
          ? vitalsNode["breathing"] as Map<String, dynamic>
          : null;
      final ecg = vitalsNode["ecg"] is Map<String, dynamic>
          ? vitalsNode["ecg"] as Map<String, dynamic>
          : null;

      final summary = _parseVitals(
        spo2,
        temp,
        breathing,
        ecg,
      );
      vitals = summary;
    }

    FitbitBodySummary? body;
    final bodyNode = data["body"];
    if (bodyNode is Map<String, dynamic>) {
      final weight = bodyNode["weight"] is Map<String, dynamic>
          ? bodyNode["weight"] as Map<String, dynamic>
          : null;
      body = _parseBody(weight);
    }

    return FitbitSummaryBundle(
      activity: activity,
      heart: heart,
      sleep: sleep,
      vitals: vitals,
      body: body,
    );
  }

  Future<FitbitSummaryBundle?> _fetchSummaryFromDb(DateTime date) async {
    final row = await FitbitDailyMetricsDbService().fetchRow(date);
    if (row == null) return null;

    int? _int(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? _double(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    FitbitActivitySummary? activity;
    if (row["steps"] != null ||
        row["distance_km"] != null ||
        row["calories_out"] != null ||
        row["floors"] != null ||
        row["active_minutes"] != null) {
      activity = FitbitActivitySummary(
        steps: _int(row["steps"]),
        distance: _double(row["distance_km"]),
        calories: _int(row["calories_out"]),
        floors: _int(row["floors"]),
        activeMinutes: _int(row["active_minutes"]),
        goalSteps: _int(row["steps_goal"]),
        goalDistance: _double(row["distance_goal_km"]),
        goalCalories: _int(row["calories_goal"]),
        goalFloors: _int(row["floors_goal"]),
        goalActiveMinutes: _int(row["active_minutes_goal"]),
      );
    }

    FitbitSleepSummary? sleep;
    if (row["sleep_minutes_asleep"] != null || row["sleep_time_in_bed"] != null) {
      sleep = FitbitSleepSummary(
        totalMinutesAsleep: _int(row["sleep_minutes_asleep"]),
        totalTimeInBed: _int(row["sleep_time_in_bed"]),
        sleepGoalMinutes: null,
        logs: const [],
      );
    }

    FitbitHeartSummary? heart;
    if (row["resting_hr"] != null ||
        row["hrv_daily_rmssd"] != null ||
        row["cardio_vo2max"] != null ||
        row["heart_zones"] != null) {
      final zonesRaw = row["heart_zones"];
      final zones = zonesRaw is List ? zonesRaw : const [];
      final vo2 = row["cardio_vo2max"]?.toString();
      heart = FitbitHeartSummary(
        restingHr: _int(row["resting_hr"]),
        hrvRmssd: _double(row["hrv_daily_rmssd"]),
        vo2Max: vo2,
        zones: zones,
      );
    }

    FitbitVitalsSummary? vitals;
    final vitalsCandidate = FitbitVitalsSummary(
      spo2Percent: _double(row["spo2_avg"]),
      spo2Min: _double(row["spo2_min"]),
      spo2Max: _double(row["spo2_max"]),
      skinTempC: _double(row["skin_temp_c"]),
      breathingRate: _double(row["breathing_rate"]),
      ecgSummary: row["ecg_summary"]?.toString(),
      ecgAvgHr: _int(row["ecg_avg_hr"]),
    );
    if (vitalsCandidate.hasAny) {
      vitals = vitalsCandidate;
    }

    FitbitBodySummary? body;
    if (row["weight_kg"] != null) {
      body = FitbitBodySummary(weightKg: _double(row["weight_kg"]));
    }

    if (activity == null && heart == null && sleep == null && vitals == null && body == null) {
      return null;
    }

    return FitbitSummaryBundle(
      activity: activity,
      heart: heart,
      sleep: sleep,
      vitals: vitals,
      body: body,
    );
  }

  FitbitVitalsSummary _parseVitals(
    Map<String, dynamic>? spo2Data,
    Map<String, dynamic>? tempData,
    Map<String, dynamic>? breathingData,
    Map<String, dynamic>? ecgData,
  ) {
    double? _double(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    String? _str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    double? spo2;
    double? spo2Min;
    double? spo2Max;
    final spo2Value = spo2Data?['value'];
    if (spo2Value is Map) {
      spo2 = _double(spo2Value['avg']);
      spo2Min = _double(spo2Value['min']);
      spo2Max = _double(spo2Value['max']);
    }

    double? tempC;
    final tempList = tempData?['tempSkin'];
    if (tempList is List && tempList.isNotEmpty) {
      final entry = tempList.first;
      if (entry is Map) {
        final value = entry['value'];
        if (value is Map) {
          tempC = _double(value['nightlyRelative']);
        }
      }
    }

    double? breathing;
    final brList = breathingData?['br'];
    if (brList is List && brList.isNotEmpty) {
      final entry = brList.first;
      if (entry is Map) {
        final value = entry['value'];
        if (value is Map) {
          breathing = _double(value['breathingRate']);
        }
      }
    }

    String? ecg;
    int? ecgAvgHr;
    final ecgList = ecgData?['ecgReadings'];
    if (ecgList is List && ecgList.isNotEmpty) {
      final entry = ecgList.first;
      if (entry is Map) {
        ecg = _str(entry['resultClassification']);
        final avg = entry['averageHeartRate'];
        if (avg is num) ecgAvgHr = avg.toInt();
        if (avg is String) ecgAvgHr = int.tryParse(avg);
      }
    }

    return FitbitVitalsSummary(
      spo2Percent: spo2,
      spo2Min: spo2Min,
      spo2Max: spo2Max,
      skinTempC: tempC,
      breathingRate: breathing,
      ecgSummary: ecg,
      ecgAvgHr: ecgAvgHr,
    );
  }

  FitbitBodySummary _parseBody(Map<String, dynamic>? weightData) {
    double? _double(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    double? weightKg;
    final weightLogs = weightData?['weight'];
    if (weightLogs is List && weightLogs.isNotEmpty) {
      final entry = weightLogs.first;
      if (entry is Map) {
        weightKg = _double(entry['weight']);
      }
    }

    return FitbitBodySummary(weightKg: weightKg);
  }
}
