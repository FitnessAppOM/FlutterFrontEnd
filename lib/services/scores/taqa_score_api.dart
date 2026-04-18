import 'dart:convert';

import 'package:http/http.dart' as http;

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
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class TaqaScoreApi {
  static final Map<String, TaqaDailyScore?> _cache = {};
  static final Map<String, Future<TaqaDailyScore?>> _inFlight = {};

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  static String _dayKey(int userId, DateTime date) =>
      "$userId|${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  static String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static Future<TaqaDailyScore?> fetchDaily({
    required int userId,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final key = _dayKey(userId, date);
    if (!forceRefresh && _cache.containsKey(key)) return _cache[key];
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
    final headers = await AccountStorage.getAuthHeaders();
    if (headers.isEmpty) return null;

    final dateStr = _fmtDate(date);
    final refreshQuery = forceRefresh ? "&refresh=true" : "";
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/scores/$userId/daily?date=$dateStr$refreshQuery",
    );

    try {
      final resp = await http.get(url, headers: headers);
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await AccountStorage.handleAuthStatus(
          resp.statusCode,
          responseBody: resp.body,
        );
        return null;
      }
      if (resp.statusCode == 404) {
        _cache[cacheKey] = null;
        return null;
      }
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body);
      if (json is! Map<String, dynamic>) return null;
      final score = TaqaDailyScore.fromJson(json);
      _cache[cacheKey] = score;
      return score;
    } catch (_) {
      return null;
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
      final resp = await http.get(url, headers: headers);
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
      return json
          .whereType<Map<String, dynamic>>()
          .map(TaqaDailyScore.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
