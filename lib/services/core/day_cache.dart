import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A cached response for one user/day. [json] may be null when the backend
/// legitimately returned "nothing" (e.g. a feature disabled for that day).
class DayCacheEntry {
  const DayCacheEntry(this.json, this.cachedAt);

  final Map<String, dynamic>? json;
  final DateTime cachedAt;
}

/// Shared per-user/per-day JSON cache (memory + SharedPreferences), following
/// the TaqaScoreApi flow:
///
/// * [read] returns the last stored response immediately (hydrating from disk
///   on first access) so pages can paint before the network answers.
/// * [write] stores a fresh response in memory and on disk, evicting the
///   oldest days beyond [persistentLimit].
/// * [dedupe] collapses concurrent loads of the same day into one request.
///
/// Services own the instance; pages only call the service.
class DayCache {
  DayCache(this.namespace, {this.persistentLimit = 120});

  /// Unique, versioned storage prefix, e.g. `calendar_day_v1`.
  final String namespace;
  final int persistentLimit;

  final Map<String, DayCacheEntry> _memory = {};
  final Set<String> _hydrated = {};
  final Map<String, Future<void>> _hydrating = {};
  final Map<String, Future<Object?>> _inFlight = {};

  static String dateToken(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String key(int userId, DateTime date) => '$userId|${dateToken(date)}';

  String get _indexKey => '${namespace}_index';
  String _storageKey(int userId, DateTime date) =>
      '${namespace}_${userId}_${dateToken(date)}';

  Future<DayCacheEntry?> read(int userId, DateTime date) async {
    await _ensureHydrated(userId, date);
    return _memory[key(userId, date)];
  }

  Future<void> write(
    int userId,
    DateTime date,
    Map<String, dynamic>? json,
  ) async {
    final entry = DayCacheEntry(json, DateTime.now());
    final k = key(userId, date);
    _memory[k] = entry;
    _hydrated.add(k);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _storageKey(userId, date);
      await prefs.setString(
        storageKey,
        jsonEncode({
          'cached_at_ms': entry.cachedAt.millisecondsSinceEpoch,
          'json': json,
        }),
      );
      final index = prefs.getStringList(_indexKey)?.toList() ?? <String>[];
      index
        ..remove(storageKey)
        ..add(storageKey);
      while (index.length > persistentLimit) {
        await prefs.remove(index.removeAt(0));
      }
      await prefs.setStringList(_indexKey, index);
    } catch (_) {
      // Memory caching still works if persistence is unavailable.
    }
  }

  /// Drops a day so the next [read] misses (e.g. after a server-side change
  /// that makes the stored copy misleading).
  Future<void> invalidate(int userId, DateTime date) async {
    final k = key(userId, date);
    _memory.remove(k);
    _hydrated.add(k);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey(userId, date));
    } catch (_) {}
  }

  /// Clears the in-memory layer (account switch). Disk entries are keyed by
  /// user id, so they can never leak across accounts.
  void clearMemory() {
    _memory.clear();
    _hydrated.clear();
    _hydrating.clear();
    _inFlight.clear();
  }

  /// Runs [load] once per user/day at a time; concurrent callers share it.
  Future<T> dedupe<T>(int userId, DateTime date, Future<T> Function() load) {
    final k = key(userId, date);
    final active = _inFlight[k];
    if (active != null) return active.then((value) => value as T);
    final future = load();
    _inFlight[k] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[k], future)) _inFlight.remove(k);
    });
  }

  Future<void> _ensureHydrated(int userId, DateTime date) async {
    final k = key(userId, date);
    if (_hydrated.contains(k) || _memory.containsKey(k)) return;
    final active = _hydrating[k];
    if (active != null) return active;
    final future = _hydrate(userId, date, k);
    _hydrating[k] = future;
    try {
      await future;
    } finally {
      _hydrating.remove(k);
      _hydrated.add(k);
    }
  }

  Future<void> _hydrate(int userId, DateTime date, String k) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(userId, date));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final ms = decoded['cached_at_ms'];
      if (ms is! num) return;
      final json = decoded['json'];
      _memory[k] = DayCacheEntry(
        json is Map ? Map<String, dynamic>.from(json) : null,
        DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
      );
    } catch (_) {
      // A malformed disk entry must never block a network load.
    }
  }
}
