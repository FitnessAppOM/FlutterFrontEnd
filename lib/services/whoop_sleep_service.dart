import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';
import '../core/account_storage.dart';

class WhoopSleepService {
  double? _parseDurationHours(Map<String, dynamic> sleep) {
    dynamic score = sleep["score"];
    final stage = score is Map<String, dynamic> ? score["stage_summary"] : null;
    if (stage is Map<String, dynamic>) {
      final light = stage["total_light_sleep_time_milli"];
      final slow = stage["total_slow_wave_sleep_time_milli"];
      final rem = stage["total_rem_sleep_time_milli"];
      if (light is num && slow is num && rem is num) {
        final totalMs = light + slow + rem;
        if (totalMs > 0) return totalMs / 3600000.0;
      }
      if (light is String && slow is String && rem is String) {
        final l = double.tryParse(light);
        final s = double.tryParse(slow);
        final r = double.tryParse(rem);
        if (l != null && s != null && r != null) {
          final totalMs = l + s + r;
          if (totalMs > 0) return totalMs / 3600000.0;
        }
      }
    }
    return null;
  }

  double? _durationFromStartEnd(Map<String, dynamic> sleep) {
    final startCandidates = [
      sleep["start"],
      sleep["start_time"],
      sleep["start_datetime"],
      sleep["start_at"],
    ];
    final endCandidates = [
      sleep["end"],
      sleep["end_time"],
      sleep["end_datetime"],
      sleep["end_at"],
    ];

    DateTime? parse(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      if (v is int) {
        final ms = v > 1000000000000 ? v : v * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
      if (v is double) {
        final ms = v > 1000000000000 ? v : v * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);
      }
      return null;
    }

    DateTime? start;
    for (final s in startCandidates) {
      start = parse(s);
      if (start != null) break;
    }
    DateTime? end;
    for (final e in endCandidates) {
      end = parse(e);
      if (end != null) break;
    }
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    if (diff.isNegative) return null;
    return diff.inMinutes / 60.0;
  }

  Future<Map<DateTime, double>> fetchDailySleep({
    required DateTime start,
    required DateTime end,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return {};

    final url = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/sleep-daily?user_id=$userId"
      "&start=${Uri.encodeComponent(start.toIso8601String())}"
      "&end=${Uri.encodeComponent(end.toIso8601String())}",
    );
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception("Status ${res.statusCode}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = data["daily"];
    if (raw is! Map<String, dynamic>) return {};

    final Map<DateTime, double> result = {};
    raw.forEach((k, v) {
      final dt = DateTime.tryParse(k);
      if (dt != null) {
        final hours = (v is num) ? v.toDouble() : double.tryParse(v.toString());
        if (hours != null) {
          result[DateTime(dt.year, dt.month, dt.day)] = hours;
        }
      }
    });
    return result;
  }

  Future<Map<DateTime, double>> fetchLatestSleepDaily() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return {};

    final url = Uri.parse("${ApiConfig.baseUrl}/whoop/latest?user_id=$userId");
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception("Status ${res.statusCode}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final sleep = data["sleep"];
    if (sleep is! Map<String, dynamic>) return {};

    final hours = _parseDurationHours(sleep) ?? _durationFromStartEnd(sleep);
    if (hours == null) return {};

    final startRaw = sleep["start"];
    DateTime? start;
    if (startRaw is String) {
      start = DateTime.tryParse(startRaw);
    }
    if (start == null) {
      start = DateTime.now();
    }
    final dayKey = DateTime(start.year, start.month, start.day);
    return {dayKey: hours};
  }

  Future<Map<String, dynamic>?> fetchLatestSleepRaw() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return null;

    final url = Uri.parse("${ApiConfig.baseUrl}/whoop/latest?user_id=$userId");
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception("Status ${res.statusCode}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final sleep = data["sleep"];
    if (sleep is! Map<String, dynamic>) return null;
    return sleep;
  }

  Future<double?> fetchSleepHoursForDay(DateTime day) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return null;

    final dateParam =
        "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$dateParam",
    );
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = data["sleep_hours"];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  Future<Map<String, dynamic>?> fetchSleepRawForDay(DateTime day) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return null;

    final dateParam =
        "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$dateParam",
    );
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final sleep = data["sleep"];
    if (sleep is! Map<String, dynamic>) return null;
    return sleep;
  }

  Future<Map<String, dynamic>?> fetchSleepDayDetails(DateTime day) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return null;

    final dateParam =
        "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$dateParam",
    );
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data;
  }
}
