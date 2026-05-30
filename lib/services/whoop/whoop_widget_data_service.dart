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
  static final Map<String, WhoopWidgetSnapshot> _snapshotCache = {};

  static DateTime _dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dayToken(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  static String _snapshotCacheKey({
    required int userId,
    required DateTime date,
  }) {
    return "$userId|${_dayToken(_dayKey(date))}";
  }

  static void _trimSnapshotCache() {
    if (_snapshotCache.length <= 120) return;
    final keys = _snapshotCache.keys.toList()..sort();
    while (_snapshotCache.length > 120 && keys.isNotEmpty) {
      _snapshotCache.remove(keys.removeAt(0));
    }
  }

  static void _cacheSnapshot({
    required int userId,
    required DateTime date,
    required WhoopWidgetSnapshot snapshot,
  }) {
    _snapshotCache[_snapshotCacheKey(userId: userId, date: date)] = snapshot;
    _trimSnapshotCache();
  }

  static WhoopWidgetSnapshot? cachedSnapshotForDate({
    required int userId,
    required DateTime date,
  }) {
    return _snapshotCache[_snapshotCacheKey(userId: userId, date: date)];
  }

  static double? cachedSleepHoursForDate({
    required int userId,
    required DateTime date,
  }) {
    return cachedSnapshotForDate(userId: userId, date: date)?.sleepHours;
  }

  static void cacheSleepHoursForDate({
    required int userId,
    required DateTime date,
    required double sleepHours,
  }) {
    final key = _snapshotCacheKey(userId: userId, date: date);
    final prev = _snapshotCache[key];
    _snapshotCache[key] = WhoopWidgetSnapshot(
      linked: prev?.linked ?? true,
      linkedKnown: prev?.linkedKnown ?? true,
      sleepHours: sleepHours,
      sleepScore: prev?.sleepScore,
      sleepDelta: prev?.sleepDelta,
      recoveryScore: prev?.recoveryScore,
      recoveryDelta: prev?.recoveryDelta,
      cycleStrain: prev?.cycleStrain,
      bodyWeightKg: prev?.bodyWeightKg,
    );
    _trimSnapshotCache();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _dateKey(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _sleepEfficiencyFromSleepPayload(dynamic sleep) {
    if (sleep is! Map<String, dynamic>) return null;
    final scoreNode = sleep["score"];
    final stage = scoreNode is Map<String, dynamic>
        ? scoreNode["stage_summary"]
        : null;
    if (stage is! Map<String, dynamic>) return null;
    final totalBed = stage["total_in_bed_time_milli"];
    final light = stage["total_light_sleep_time_milli"];
    final slow = stage["total_slow_wave_sleep_time_milli"];
    final rem = stage["total_rem_sleep_time_milli"];
    if (totalBed is num &&
        light is num &&
        slow is num &&
        rem is num &&
        totalBed > 0) {
      final sleepMs = light + slow + rem;
      return ((sleepMs / totalBed) * 100).round();
    }
    return null;
  }

  int? _sleepEfficiencyFromDbRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final totalSleepMinutes = _asDouble(row["total_sleep_minutes"]);
    final timeInBedMinutes = _asDouble(row["time_in_bed_minutes"]);
    if (totalSleepMinutes == null ||
        timeInBedMinutes == null ||
        timeInBedMinutes <= 0) {
      return null;
    }
    return ((totalSleepMinutes / timeInBedMinutes) * 100).round();
  }

  Future<Map<String, dynamic>?> _fetchDbRowForDate({
    required int userId,
    required DateTime date,
    required Map<String, String> headers,
  }) async {
    final dateParam = _dateKey(date);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/daily-metrics/range?user_id=$userId&start=$dateParam&end=$dateParam",
    );
    final res = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }

  Future<WhoopWidgetSnapshot> fetchForDate(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) {
      return const WhoopWidgetSnapshot(linked: false, linkedKnown: true);
    }

    final headers = await AccountStorage.getAuthHeaders();
    final statusUrl = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/status?user_id=$userId&backfill=0",
    );
    final statusRes = await http
        .get(statusUrl, headers: headers)
        .timeout(const Duration(seconds: 12));
    if (statusRes.statusCode != 200) {
      throw Exception("Status ${statusRes.statusCode}");
    }
    final statusData = jsonDecode(statusRes.body) as Map<String, dynamic>;
    final linked = statusData["linked"] == true;
    if (!linked) {
      const snapshot = WhoopWidgetSnapshot(linked: false, linkedKnown: true);
      _cacheSnapshot(userId: userId, date: date, snapshot: snapshot);
      return snapshot;
    }

    final isToday = _isToday(date);
    if (!isToday) {
      final row = await _fetchDbRowForDate(
        userId: userId,
        date: date,
        headers: headers,
      );
      final yesterday = date.subtract(const Duration(days: 1));
      final yRow = await _fetchDbRowForDate(
        userId: userId,
        date: yesterday,
        headers: headers,
      );

      final sleepMinutes = _asDouble(row?["total_sleep_minutes"]);
      final sleepHours = sleepMinutes == null ? null : sleepMinutes / 60.0;
      final sleepScore = _sleepEfficiencyFromDbRow(row);
      final ySleepScore = _sleepEfficiencyFromDbRow(yRow);
      final sleepDelta = (sleepScore != null && ySleepScore != null)
          ? (sleepScore - ySleepScore)
          : null;

      final recoveryScore = _asInt(row?["recovery_score"]);
      final yRecovery = _asInt(yRow?["recovery_score"]);
      final recoveryDelta = (recoveryScore != null && yRecovery != null)
          ? (recoveryScore - yRecovery)
          : null;

      final cycleStrain = _asDouble(row?["strain"]);

      final snapshot = WhoopWidgetSnapshot(
        linked: true,
        linkedKnown: true,
        sleepHours: sleepHours,
        sleepScore: sleepScore,
        sleepDelta: sleepDelta,
        recoveryScore: recoveryScore,
        recoveryDelta: recoveryDelta,
        cycleStrain: cycleStrain,
        bodyWeightKg: null,
      );
      _cacheSnapshot(userId: userId, date: date, snapshot: snapshot);
      return snapshot;
    }

    final dateParam = _dateKey(date);
    final dataUrl = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$dateParam",
    );
    final dataRes = await http
        .get(dataUrl, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (dataRes.statusCode != 200) {
      throw Exception("Status ${dataRes.statusCode}");
    }
    final data = jsonDecode(dataRes.body) as Map<String, dynamic>;

    final sleepHours = _asDouble(data["sleep_hours"]);
    final sleepScore = _sleepEfficiencyFromSleepPayload(data["sleep"]);

    int? sleepDelta;
    int? recoveryDelta;
    final recoveryScore = _asInt(data["recovery_score"]);
    double? yesterdayCycleStrain;

    final yesterday = date.subtract(const Duration(days: 1));
    final yParam = _dateKey(yesterday);
    final yUrl = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$yParam",
    );
    final yRes = await http
        .get(yUrl, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (yRes.statusCode == 200) {
      final yData = jsonDecode(yRes.body) as Map<String, dynamic>;
      final yEfficiency = _sleepEfficiencyFromSleepPayload(yData["sleep"]);
      if (sleepScore != null && yEfficiency != null) {
        sleepDelta = sleepScore - yEfficiency;
      }
      final yRecovery = _asInt(yData["recovery_score"]);
      if (recoveryScore != null && yRecovery != null) {
        recoveryDelta = recoveryScore - yRecovery;
      }
      yesterdayCycleStrain = _asDouble(yData["cycle_strain"]);
    }

    // For current-day display, always use the last completed day's cycle strain.
    final cycleStrain = yesterdayCycleStrain;

    double? bodyWeightKg;
    try {
      final latest = await WhoopLatestService.fetch();
      final body = latest?["body_measurement"];
      if (body is Map<String, dynamic>) {
        bodyWeightKg = _asDouble(body["weight_kilogram"]);
      }
    } catch (_) {
      bodyWeightKg = null;
    }

    final snapshot = WhoopWidgetSnapshot(
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
    _cacheSnapshot(userId: userId, date: date, snapshot: snapshot);
    return snapshot;
  }
}
