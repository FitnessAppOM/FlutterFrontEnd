import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../../core/date_utils.dart';

class DailyJournalEntry {
  final DateTime entryDate;
  final double? sleepHours;
  final int? sleepQuality;
  final bool? caffeineYes;
  final int? caffeineCups;
  final bool? alcoholYes;
  final int? alcoholDrinks;
  final double? hydrationLiters;
  final bool? sorenessOrPain;
  final int? sorenessLevel;
  final int? wakeUpCount;
  final int? stressLevel;
  final int? moodUponWaking;
  final bool? sexualActivity;
  final bool? screenTimeBeforeBed;
  final int? productivityFocus;
  final int? motivationToTrain;
  final bool? tookSupplementsOrMedications;

  DailyJournalEntry({
    required this.entryDate,
    this.sleepHours,
    this.sleepQuality,
    this.caffeineYes,
    this.caffeineCups,
    this.alcoholYes,
    this.alcoholDrinks,
    this.hydrationLiters,
    this.sorenessOrPain,
    this.sorenessLevel,
    this.wakeUpCount,
    this.stressLevel,
    this.moodUponWaking,
    this.sexualActivity,
    this.screenTimeBeforeBed,
    this.productivityFocus,
    this.motivationToTrain,
    this.tookSupplementsOrMedications,
  });

  factory DailyJournalEntry.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      throw ArgumentError('Invalid entry_date');
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      return value.toString().toLowerCase() == 'true';
    }

    return DailyJournalEntry(
      entryDate: parseDate(json['entry_date']),
      sleepHours: parseDouble(json['sleep_hours']),
      sleepQuality: parseInt(json['sleep_quality']),
      caffeineYes: parseBool(json['caffeine_yes']),
      caffeineCups: parseInt(json['caffeine_cups']),
      alcoholYes: parseBool(json['alcohol_yes']),
      alcoholDrinks: parseInt(json['alcohol_drinks']),
      hydrationLiters: parseDouble(json['hydration_liters']),
      sorenessOrPain: parseBool(json['soreness_or_pain']),
      sorenessLevel: parseInt(json['soreness_level']),
      wakeUpCount: parseInt(json['wake_up_count']),
      stressLevel: parseInt(json['stress_level']),
      moodUponWaking: parseInt(json['mood_upon_waking']),
      sexualActivity: parseBool(json['sexual_activity']),
      screenTimeBeforeBed: parseBool(json['screen_time_before_bed']),
      productivityFocus: parseInt(json['productivity_focus']),
      motivationToTrain: parseInt(json['motivation_to_train']),
      tookSupplementsOrMedications: parseBool(
        json['took_supplements_or_medications'],
      ),
    );
  }
}

class DailyJournalApi {
  static final Map<String, DailyJournalEntry?> _cache = {};
  static final Map<String, Future<DailyJournalEntry?>> _inFlight = {};

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  static Future<DailyJournalEntry?> fetchLatest(int userId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/daily-journal/$userId/latest");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return DailyJournalEntry.fromJson(data);
    }

    if (res.statusCode == 404) {
      return null;
    }

    throw Exception("Failed to fetch daily journal: ${res.body}");
  }

  static Future<DailyJournalEntry?> fetchForDate(
    int userId,
    DateTime date,
  ) async {
    final dateStr = date.toIso8601String().split("T").first;
    final todayStr = DateTime.now().toIso8601String().split("T").first;
    final cacheKey = "$userId-$dateStr";

    // Past-day entries never change from outside this page, so serve them
    // from cache when switching between dates — only a fresh pull-to-refresh
    // or a save for that date should hit the network again.
    if (dateStr != todayStr && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    if (_inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey];
    }

    final url = Uri.parse(
      "${ApiConfig.baseUrl}/daily-journal/$userId/date/$dateStr",
    );
    final future = http.get(url).then((res) {
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return DailyJournalEntry.fromJson(data);
      }
      if (res.statusCode == 404) return null;
      throw Exception("Failed to fetch daily journal for $dateStr: ${res.body}");
    });

    _inFlight[cacheKey] = future;
    try {
      final result = await future;
      if (dateStr != todayStr) {
        _cache[cacheKey] = result;
      }
      return result;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static Future<void> upsert({
    required int userId,
    DateTime? entryDate,
    double? sleepHours,
    int? sleepQuality,
    bool? caffeineYes,
    int? caffeineCups,
    bool? alcoholYes,
    int? alcoholDrinks,
    double? hydrationLiters,
    bool? sorenessOrPain,
    int? sorenessLevel,
    int? wakeUpCount,
    int? stressLevel,
    int? moodUponWaking,
    bool? sexualActivity,
    bool? screenTimeBeforeBed,
    int? productivityFocus,
    int? motivationToTrain,
    bool? tookSupplementsOrMedications,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/daily-journal/");
    final effectiveEntryDate = dateOnly(entryDate ?? localYesterday());
    final body = <String, dynamic>{
      "user_id": userId,
      "entry_date": effectiveEntryDate.toIso8601String().split("T").first,
      if (sleepHours != null) "sleep_hours": sleepHours,
      if (sleepQuality != null) "sleep_quality": sleepQuality,
      if (caffeineYes != null) "caffeine_yes": caffeineYes,
      if (caffeineCups != null) "caffeine_cups": caffeineCups,
      if (alcoholYes != null) "alcohol_yes": alcoholYes,
      if (alcoholDrinks != null) "alcohol_drinks": alcoholDrinks,
      if (hydrationLiters != null) "hydration_liters": hydrationLiters,
      if (sorenessOrPain != null) "soreness_or_pain": sorenessOrPain,
      if (sorenessLevel != null) "soreness_level": sorenessLevel,
      if (wakeUpCount != null) "wake_up_count": wakeUpCount,
      if (stressLevel != null) "stress_level": stressLevel,
      if (moodUponWaking != null) "mood_upon_waking": moodUponWaking,
      if (sexualActivity != null) "sexual_activity": sexualActivity,
      if (screenTimeBeforeBed != null)
        "screen_time_before_bed": screenTimeBeforeBed,
      if (productivityFocus != null) "productivity_focus": productivityFocus,
      if (motivationToTrain != null) "motivation_to_train": motivationToTrain,
      if (tookSupplementsOrMedications != null)
        "took_supplements_or_medications": tookSupplementsOrMedications,
    };

    final headers = {
      "Content-Type": "application/json",
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(url, headers: headers, body: jsonEncode(body));

    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode == 200) {
      final dateStr = effectiveEntryDate.toIso8601String().split("T").first;
      _cache.remove("$userId-$dateStr");
      return;
    }
    if (res.statusCode == 409) {
      throw Exception("already_submitted");
    }
    throw Exception("Failed to save daily journal: ${res.body}");
  }
}
