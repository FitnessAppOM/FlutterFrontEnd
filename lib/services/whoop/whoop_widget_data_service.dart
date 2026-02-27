import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'whoop_latest_service.dart';

class WhoopWidgetSnapshot {
  const WhoopWidgetSnapshot({
    required this.linked,
    required this.linkedKnown,
    this.sleepHours,
    this.sleepScore,
    this.sleepDelta,
    this.recoveryScore,
    this.recoveryDelta,
    this.cycleStrain,
    this.bodyWeightKg,
  });

  final bool linked;
  final bool linkedKnown;
  final double? sleepHours;
  final int? sleepScore;
  final int? sleepDelta;
  final int? recoveryScore;
  final int? recoveryDelta;
  final double? cycleStrain;
  final double? bodyWeightKg;
}

class WhoopWidgetDataService {
  Future<WhoopWidgetSnapshot> fetchForDate(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) {
      return const WhoopWidgetSnapshot(linked: false, linkedKnown: true);
    }

    final headers = await AccountStorage.getAuthHeaders();
    final statusUrl = Uri.parse("${ApiConfig.baseUrl}/whoop/status?user_id=$userId");
    final statusRes =
        await http.get(statusUrl, headers: headers).timeout(const Duration(seconds: 12));
    if (statusRes.statusCode != 200) {
      throw Exception("Status ${statusRes.statusCode}");
    }
    final statusData = jsonDecode(statusRes.body) as Map<String, dynamic>;
    final linked = statusData["linked"] == true;
    if (!linked) {
      return const WhoopWidgetSnapshot(linked: false, linkedKnown: true);
    }

    final dateParam =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final dataUrl = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$dateParam",
    );
    final dataRes =
        await http.get(dataUrl, headers: headers).timeout(const Duration(seconds: 20));
    if (dataRes.statusCode != 200) {
      throw Exception("Status ${dataRes.statusCode}");
    }
    final data = jsonDecode(dataRes.body) as Map<String, dynamic>;

    final sleepHours = data["sleep_hours"] is num
        ? (data["sleep_hours"] as num).toDouble()
        : double.tryParse("${data["sleep_hours"]}");

    int? sleepScore;
    final sleep = data["sleep"];
    if (sleep is Map<String, dynamic>) {
      final scoreNode = sleep["score"];
      final stage = scoreNode is Map<String, dynamic> ? scoreNode["stage_summary"] : null;
      if (stage is Map<String, dynamic>) {
        final totalBed = stage["total_in_bed_time_milli"];
        final light = stage["total_light_sleep_time_milli"];
        final slow = stage["total_slow_wave_sleep_time_milli"];
        final rem = stage["total_rem_sleep_time_milli"];
        if (totalBed is num && light is num && slow is num && rem is num && totalBed > 0) {
          final sleepMs = light + slow + rem;
          sleepScore = ((sleepMs / totalBed) * 100).round();
        }
      }
    }

    int? sleepDelta;
    int? recoveryDelta;
    final yesterday = date.subtract(const Duration(days: 1));
    final yParam =
        "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    final yUrl = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$yParam",
    );
    final yRes =
        await http.get(yUrl, headers: headers).timeout(const Duration(seconds: 20));
    if (yRes.statusCode == 200) {
      final yData = jsonDecode(yRes.body) as Map<String, dynamic>;
      int? yEfficiency;
      final ySleep = yData["sleep"];
      if (ySleep is Map<String, dynamic>) {
        final scoreNode = ySleep["score"];
        final stage = scoreNode is Map<String, dynamic> ? scoreNode["stage_summary"] : null;
        if (stage is Map<String, dynamic>) {
          final totalBed = stage["total_in_bed_time_milli"];
          final light = stage["total_light_sleep_time_milli"];
          final slow = stage["total_slow_wave_sleep_time_milli"];
          final rem = stage["total_rem_sleep_time_milli"];
          if (totalBed is num && light is num && slow is num && rem is num && totalBed > 0) {
            final sleepMs = light + slow + rem;
            yEfficiency = ((sleepMs / totalBed) * 100).round();
          }
        }
      }
      if (sleepScore != null && yEfficiency != null) {
        sleepDelta = sleepScore - yEfficiency;
      }
      final yRecovery = yData["recovery_score"] is num
          ? (yData["recovery_score"] as num).round()
          : int.tryParse("${yData["recovery_score"]}");
      if (yRecovery != null) {
        recoveryDelta = -yRecovery;
      }
    }

    final recoveryScore = data["recovery_score"] is num
        ? (data["recovery_score"] as num).round()
        : int.tryParse("${data["recovery_score"]}");
    if (recoveryScore != null && recoveryDelta != null) {
      recoveryDelta = recoveryScore + recoveryDelta;
    } else {
      recoveryDelta = null;
    }

    double? cycleStrain;
    final rawCycle = data["cycle_strain"];
    if (rawCycle is num) cycleStrain = rawCycle.toDouble();
    if (rawCycle is String) cycleStrain = double.tryParse(rawCycle);

    double? bodyWeightKg;
    try {
      final latest = await WhoopLatestService.fetch();
      final body = latest?["body_measurement"];
      if (body is Map<String, dynamic>) {
        final raw = body["weight_kilogram"];
        if (raw is num) bodyWeightKg = raw.toDouble();
        if (raw is String) bodyWeightKg = double.tryParse(raw);
      }
    } catch (_) {
      bodyWeightKg = null;
    }

    return WhoopWidgetSnapshot(
      linked: true,
      linkedKnown: true,
      sleepHours: sleepHours,
      sleepScore: sleepScore,
      sleepDelta: sleepDelta,
      recoveryScore: recoveryScore,
      recoveryDelta: recoveryDelta,
      cycleStrain: cycleStrain,
      bodyWeightKg: bodyWeightKg,
    );
  }
}
