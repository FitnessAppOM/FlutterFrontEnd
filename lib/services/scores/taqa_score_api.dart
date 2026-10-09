import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class TaqaSubScore {
  final double? score;
  final String? path;
  final Map<String, dynamic> details;

  const TaqaSubScore({this.score, this.path, this.details = const {}});

  factory TaqaSubScore.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TaqaSubScore();
    final score = _toDouble(json['score']);
    final path = json['path'] as String?;
    final details = Map<String, dynamic>.from(json)
      ..remove('score')
      ..remove('path');
    return TaqaSubScore(score: score, path: path, details: details);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...details,
    'score': score,
    'path': path,
  };
}

class TaqaPromScores {
  final double? eq5dScore;
  final double? phq2Score;
  final int? phq2Total;
  final List<String> flags;
  final String? path;
  final String? screeningCreatedAt;

  const TaqaPromScores({
    this.eq5dScore,
    this.phq2Score,
    this.phq2Total,
    this.flags = const [],
    this.path,
    this.screeningCreatedAt,
  });

  factory TaqaPromScores.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TaqaPromScores();
    final rawFlags = json['flags'];
    final flags = rawFlags is List
        ? rawFlags.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return TaqaPromScores(
      eq5dScore: _toDouble(json['eq5d_score']),
      phq2Score: _toDouble(json['phq2_score']),
      phq2Total: json['phq2_total'] is num
          ? (json['phq2_total'] as num).toInt()
          : int.tryParse('${json['phq2_total'] ?? ''}'),
      flags: flags,
      path: json['path'] as String?,
      screeningCreatedAt: json['screening_created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'eq5d_score': eq5dScore,
    'phq2_score': phq2Score,
    'phq2_total': phq2Total,
    'flags': flags,
    'path': path,
    'screening_created_at': screeningCreatedAt,
  };
}

class TaqaDailyScore {
  final int userId;
  final DateTime entryDate;
  final String? provider;
  final String? scoringPath;
  final double? taqaValueScore;
  final TaqaSubScore sleep;
  final TaqaSubScore recovery;
  final TaqaSubScore stress;
  final TaqaSubScore trainingLoad;
  final TaqaSubScore nutrition;
  final TaqaSubScore readiness;
  final TaqaSubScore lifestyleBalance;
  final TaqaPromScores proms;

  const TaqaDailyScore({
    required this.userId,
    required this.entryDate,
    this.provider,
    this.scoringPath,
    this.taqaValueScore,
    this.sleep = const TaqaSubScore(),
    this.recovery = const TaqaSubScore(),
    this.stress = const TaqaSubScore(),
    this.trainingLoad = const TaqaSubScore(),
    this.nutrition = const TaqaSubScore(),
    this.readiness = const TaqaSubScore(),
    this.lifestyleBalance = const TaqaSubScore(),
    this.proms = const TaqaPromScores(),
  });

  factory TaqaDailyScore.fromJson(Map<String, dynamic> json) {
    return TaqaDailyScore(
      userId: (json['user_id'] as num).toInt(),
      entryDate: DateTime.parse(json['entry_date'] as String),
      provider: json['provider'] as String?,
      scoringPath: json['scoring_path'] as String?,
      taqaValueScore: _toDouble(json['taqa_value_score']),
      sleep: TaqaSubScore.fromJson(json['sleep'] as Map<String, dynamic>?),
      recovery: TaqaSubScore.fromJson(
        json['recovery'] as Map<String, dynamic>?,
      ),
      stress: TaqaSubScore.fromJson(json['stress'] as Map<String, dynamic>?),
      trainingLoad: TaqaSubScore.fromJson(
        json['training_load'] as Map<String, dynamic>?,
      ),
      nutrition: TaqaSubScore.fromJson(
        json['nutrition'] as Map<String, dynamic>?,
      ),
      readiness: TaqaSubScore.fromJson(
        json['readiness'] as Map<String, dynamic>?,
      ),
      lifestyleBalance: TaqaSubScore.fromJson(
        json['lifestyle_balance'] as Map<String, dynamic>?,
      ),
      proms: TaqaPromScores.fromJson(json['proms'] as Map<String, dynamic>?),
    );
  }

  bool get hasReadiness =>
      readiness.score != null && readiness.path != 'no_wearable';

  bool get hasLifestyleBalance => lifestyleBalance.score != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'entry_date':
        '${entryDate.year.toString().padLeft(4, '0')}-'
        '${entryDate.month.toString().padLeft(2, '0')}-'
        '${entryDate.day.toString().padLeft(2, '0')}',
    'provider': provider,
    'scoring_path': scoringPath,
    'taqa_value_score': taqaValueScore,
    'sleep': sleep.toJson(),
    'recovery': recovery.toJson(),
    'stress': stress.toJson(),
    'training_load': trainingLoad.toJson(),
    'nutrition': nutrition.toJson(),
    'readiness': readiness.toJson(),
    'lifestyle_balance': lifestyleBalance.toJson(),
    'proms': proms.toJson(),
  };
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class TaqaScoreApi {
  static final Map<String, TaqaDailyScore?> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static final Map<String, Future<TaqaDailyScore?>> _inFlight = {};
  static final Map<String, DateTime> _networkFailureAt = {};
  static final Set<String> _hydratedKeys = <String>{};
  static final Map<String, Future<void>> _hydrateInFlight =
      <String, Future<void>>{};
  static const Duration _liveDayTtl = Duration(seconds: 60);
  static const Duration _negativeCacheTtl = Duration(minutes: 5);
  static const Duration _networkTimeout = Duration(seconds: 8);
  static const Duration _networkFailureBackoff = Duration(seconds: 30);
  static const String _persistentPrefix = 'taqa_score_cache_v1_';
  static const String _persistentIndexKey = 'taqa_score_cache_v1_index';
  static const int _persistentEntryLimit = 180;

  static void clearCache() {
    _cache.clear();
    _cacheAt.clear();
    _inFlight.clear();
    _networkFailureAt.clear();
    _hydratedKeys.clear();
    _hydrateInFlight.clear();
  }

  static String _dayKey(int userId, DateTime date) =>
      "$userId|${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  static String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static bool _isLiveDate(DateTime date) {
    final now = DateTime.now();
    final liveDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);
    return target == liveDay;
  }

  static bool _isCacheFresh(String key, DateTime date) {
    if (!_cache.containsKey(key)) return false;
    final cachedAt = _cacheAt[key];
    if (cachedAt == null) return false;
    if (_cache[key] == null) {
      return DateTime.now().difference(cachedAt) <= _negativeCacheTtl;
    }
    if (!_isLiveDate(date)) return true;
    return DateTime.now().difference(cachedAt) <= _liveDayTtl;
  }

  static String _persistentKey(int userId, DateTime date) =>
      '$_persistentPrefix${userId}_${_fmtDate(date)}';

  static Future<void> _ensureHydrated(int userId, DateTime date) async {
    final cacheKey = _dayKey(userId, date);
    if (_hydratedKeys.contains(cacheKey) || _cache.containsKey(cacheKey)) {
      return;
    }
    final active = _hydrateInFlight[cacheKey];
    if (active != null) {
      await active;
      return;
    }
    final future = _hydratePersistentEntry(userId, date, cacheKey);
    _hydrateInFlight[cacheKey] = future;
    try {
      await future;
    } finally {
      _hydrateInFlight.remove(cacheKey);
      _hydratedKeys.add(cacheKey);
    }
  }

  static Future<void> _hydratePersistentEntry(
    int userId,
    DateTime date,
    String cacheKey,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_persistentKey(userId, date));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final record = Map<String, dynamic>.from(decoded);
      final cachedAtMs = record['cached_at_ms'];
      final cachedAt = cachedAtMs is num
          ? DateTime.fromMillisecondsSinceEpoch(cachedAtMs.toInt())
          : null;
      if (cachedAt == null) return;
      final rawScore = record['score'];
      TaqaDailyScore? score;
      if (rawScore is Map) {
        score = TaqaDailyScore.fromJson(Map<String, dynamic>.from(rawScore));
        if (score.userId != userId) return;
      }
      _cache[cacheKey] = score;
      _cacheAt[cacheKey] = cachedAt;
    } catch (_) {
      // A malformed or unavailable disk cache must never block a network load.
    }
  }

  static Future<void> _writeCacheEntry({
    required int userId,
    required DateTime date,
    required String cacheKey,
    required TaqaDailyScore? score,
  }) async {
    final cachedAt = DateTime.now();
    _cache[cacheKey] = score;
    _cacheAt[cacheKey] = cachedAt;
    _hydratedKeys.add(cacheKey);
    try {
      final preferences = await SharedPreferences.getInstance();
      final storageKey = _persistentKey(userId, date);
      await preferences.setString(
        storageKey,
        jsonEncode(<String, dynamic>{
          'cached_at_ms': cachedAt.millisecondsSinceEpoch,
          'score': score?.toJson(),
        }),
      );
      final index =
          preferences.getStringList(_persistentIndexKey)?.toList() ??
          <String>[];
      index.remove(storageKey);
      index.add(storageKey);
      while (index.length > _persistentEntryLimit) {
        final oldest = index.removeAt(0);
        await preferences.remove(oldest);
      }
      await preferences.setStringList(_persistentIndexKey, index);
    } catch (_) {
      // Memory caching remains available if persistence fails.
    }
  }

  /// Returns the last stored score immediately, even when its live-day TTL has
  /// expired. Callers can paint it first and revalidate in the background.
  static Future<TaqaDailyScore?> readCachedDaily({
    required int userId,
    required DateTime date,
  }) async {
    await _ensureHydrated(userId, date);
    return _cache[_dayKey(userId, date)];
  }

  static Future<TaqaDailyScore?> fetchDaily({
    required int userId,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final key = _dayKey(userId, date);
    await _ensureHydrated(userId, date);
    if (!forceRefresh && _isCacheFresh(key, date)) return _cache[key];
    final failedAt = _networkFailureAt[key];
    if (!forceRefresh &&
        failedAt != null &&
        DateTime.now().difference(failedAt) <= _networkFailureBackoff) {
      return _cache[key];
    }
    if (_inFlight.containsKey(key)) return _inFlight[key];

    final future = _doFetchDaily(userId, date, key, forceRefresh);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<TaqaDailyScore?> _doFetchDaily(
    int userId,
    DateTime date,
    String cacheKey,
    bool forceRefresh,
  ) async {
    final hasFallback = _cache.containsKey(cacheKey);
    final fallback = _cache[cacheKey];
    final headers = await AccountStorage.getAuthHeaders();
    if (headers.isEmpty) {
      _networkFailureAt[cacheKey] = DateTime.now();
      return hasFallback ? fallback : null;
    }

    final dateStr = _fmtDate(date);
    final refreshQuery = forceRefresh ? "&refresh=true" : "";
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/scores/$userId/daily?date=$dateStr$refreshQuery",
    );

    try {
      final resp = await http
          .get(url, headers: headers)
          .timeout(_networkTimeout);
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await AccountStorage.handleAuthStatus(
          resp.statusCode,
          responseBody: resp.body,
        );
        return null;
      }
      if (resp.statusCode == 404) {
        _networkFailureAt.remove(cacheKey);
        await _writeCacheEntry(
          userId: userId,
          date: date,
          cacheKey: cacheKey,
          score: null,
        );
        return null;
      }
      if (resp.statusCode != 200) {
        _networkFailureAt[cacheKey] = DateTime.now();
        return hasFallback ? fallback : null;
      }

      final json = jsonDecode(resp.body);
      if (json is! Map<String, dynamic>) {
        _networkFailureAt[cacheKey] = DateTime.now();
        return hasFallback ? fallback : null;
      }
      final score = TaqaDailyScore.fromJson(json);
      _networkFailureAt.remove(cacheKey);
      await _writeCacheEntry(
        userId: userId,
        date: date,
        cacheKey: cacheKey,
        score: score,
      );
      return score;
    } catch (_) {
      _networkFailureAt[cacheKey] = DateTime.now();
      return hasFallback ? fallback : null;
    }
  }

  static Future<List<TaqaDailyScore>> fetchRange({
    required int userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final headers = await AccountStorage.getAuthHeaders();
    if (headers.isEmpty) return const [];

    final startStr = _fmtDate(start);
    final endStr = _fmtDate(end);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/scores/$userId/range?start=$startStr&end=$endStr",
    );

    try {
      final resp = await http
          .get(url, headers: headers)
          .timeout(_networkTimeout);
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await AccountStorage.handleAuthStatus(
          resp.statusCode,
          responseBody: resp.body,
        );
        return const [];
      }
      if (resp.statusCode != 200) return const [];

      final json = jsonDecode(resp.body);
      if (json is! List) return const [];
      final scores = json
          .whereType<Map<String, dynamic>>()
          .map(TaqaDailyScore.fromJson)
          .toList();
      for (final score in scores) {
        await _writeCacheEntry(
          userId: userId,
          date: score.entryDate,
          cacheKey: _dayKey(userId, score.entryDate),
          score: score,
        );
      }
      return scores;
    } catch (_) {
      return const [];
    }
  }
}
