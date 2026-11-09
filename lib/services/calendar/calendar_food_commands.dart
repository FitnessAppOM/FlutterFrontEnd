import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../core/network_status_service.dart';
import '../diet/diet_action_queue.dart';
import 'calendar_diet_refresh.dart';
import 'day_timeline_service.dart';

String calendarDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CalendarCommandError implements Exception {
  const CalendarCommandError(this.messageKey, {this.reload = false});
  final String messageKey;
  final bool reload;
}

class CalendarFoodState {
  CalendarFoodState.fromJson(Map<String, dynamic> json)
    : source = Map<String, dynamic>.unmodifiable(json['source'] as Map),
      date = DateTime.parse(json['entry_date'] as String),
      scheduledAt = DateTime.tryParse(json['scheduled_at']?.toString() ?? ''),
      title = json['title']?.toString() ?? '',
      canEditTime = (json['capabilities'] as List).contains('edit_time'),
      canCopy = (json['capabilities'] as List).contains('copy'),
      canBulk = (json['capabilities'] as List).contains('bulk'),
      canRecipe = (json['capabilities'] as List).contains('create_recipe'),
      canEditContents = (json['capabilities'] as List).contains(
        'edit_contents',
      ),
      items = (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((i) => Map<String, dynamic>.from(i))
          .toList(),
      overrides = (json['overrides'] as List?)?.cast<num?>();

  final Map<String, dynamic> source;
  final DateTime date;
  final DateTime? scheduledAt;
  final String title;
  final bool canEditTime;
  final bool canCopy;
  final bool canBulk;
  final bool canRecipe;
  final bool canEditContents;
  final List<Map<String, dynamic>> items;
  final List<num?>? overrides;
  String get kind => source['kind'] as String;
  int get id => source['id'] as int;
}

/// A single unresolved request per account. This is a receipt for manual retry,
/// never an offline queue and never automatically submitted on startup.
class PendingCalendarMove {
  PendingCalendarMove({
    required this.sourceDate,
    required this.title,
    required Map<String, dynamic> request,
    this.action = 'reschedule',
    List<DateTime>? sourceDates,
    List<DateTime>? consumedSourceDates,
  }) : sourceDates = sourceDates ?? [sourceDate],
       consumedSourceDates = consumedSourceDates ?? sourceDates ?? [sourceDate],
       encodedRequest = jsonEncode(request);
  PendingCalendarMove.fromJson(Map<String, dynamic> json)
    : sourceDate = DateTime.parse(json['source_date'] as String),
      title = json['title'] as String,
      action = json['action'] as String? ?? 'reschedule',
      sourceDates = (json['source_dates'] as List? ?? [json['source_date']])
          .map((d) => DateTime.parse(d as String))
          .toList(),
      consumedSourceDates =
          (json['consumed_source_dates'] as List? ??
                  json['source_dates'] as List? ??
                  [json['source_date']])
              .map((d) => DateTime.parse(d as String))
              .toList(),
      encodedRequest = json['request'] as String;

  final DateTime sourceDate;
  final List<DateTime> sourceDates;
  final List<DateTime> consumedSourceDates;
  final String title;
  final String encodedRequest;
  final String action;
  bool get isCopy => action == 'copy';
  bool get isBulk => action == 'bulk';
  bool get isDetails => {'recipe', 'recipe-log', 'edit-item'}.contains(action);
  Map<String, dynamic> get request =>
      jsonDecode(encodedRequest) as Map<String, dynamic>;
  Map get _firstSource => action == 'recipe-log'
      ? {'kind': 'recipe', 'id': request['recipe']['id']}
      : isBulk || action == 'recipe'
      ? request['entries'][0]['source'] as Map
      : request['source'] as Map;
  String get kind => _firstSource['kind'] as String;
  int get id => _firstSource['id'] as int;
  List<Map<String, dynamic>> get destinations => action == 'recipe-log'
      ? [Map<String, dynamic>.from(request['destination'] as Map)]
      : action == 'recipe' || action == 'edit-item'
      ? []
      : isBulk
      ? (request['entries'] as List)
            .expand((e) => e['destinations'] as List)
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList()
      : isCopy
      ? (request['destinations'] as List)
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList()
      : [request];
  DateTime get destinationDate =>
      DateTime.parse(destinations.first['scheduled_date'] as String);
  Map<String, dynamic> toJson() => {
    'source_date': calendarDate(sourceDate),
    'source_dates': sourceDates.map(calendarDate).toList(),
    'consumed_source_dates': consumedSourceDates.map(calendarDate).toList(),
    'title': title,
    'request': encodedRequest,
    'action': action,
  };
}

class CalendarFoodCommands {
  static final changes = ValueNotifier<int>(0);
  static final Set<int> _busy = {};
  static String _key(int userId) => 'calendar_pending_move_u$userId';

  static Future<void> _requireAccount(int userId) async {
    if (await AccountStorage.getUserId() != userId) {
      throw const CalendarCommandError('calendar_time_account_changed');
    }
  }

  static Future<PendingCalendarMove?> pending(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    return raw == null
        ? null
        : PendingCalendarMove.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<CalendarFoodState?> fetchState(
    int userId,
    String kind,
    int id,
  ) async {
    await _requireAccount(userId);
    final headers = await AccountStorage.getAuthHeaders();
    await _requireAccount(userId);
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/calendar/$userId/food/$kind/$id'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    await _requireAccount(userId);
    await AccountStorage.handle401(response.statusCode);
    // Old/disabled backends must not remove the existing meal edit actions.
    if ({404, 405, 503}.contains(response.statusCode)) return null;
    if (response.statusCode != 200) {
      throw const CalendarCommandError('calendar_time_load_error');
    }
    final state = CalendarFoodState.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (state.kind != kind || state.id != id) {
      throw const FormatException('Mismatched food');
    }
    return state;
  }

  static Future<void> _guardDates(int userId, PendingCalendarMove move) async {
    for (final day in {
      ...move.sourceDates,
      ...move.destinations.map(
        (d) => DateTime.parse(d['scheduled_date'] as String),
      ),
    }) {
      if (await DietActionQueue.hasPendingForDate(userId, day)) {
        throw const CalendarCommandError('calendar_time_pending_diet');
      }
    }
  }

  static Future<void> move({
    required int userId,
    required CalendarFoodState state,
    required String timestamp,
    required String timezone,
    required DateTime destination,
  }) async {
    if (!state.canEditTime) {
      throw const CalendarCommandError('calendar_time_unavailable');
    }
    final request = PendingCalendarMove(
      sourceDate: state.date,
      title: state.title,
      request: {
        'operation_key': DayTimelineService.newEntryKey(userId),
        'source': state.source,
        'scheduled_date': calendarDate(destination),
        'scheduled_at': timestamp,
        'timezone': timezone,
      },
    );
    await _run(userId, request);
  }

  static Future<void> retry(int userId) => _run(userId, null);

  static Future<Map<String, dynamic>?> readRecipes(
    int userId, [
    int? recipeId,
  ]) async {
    await _requireAccount(userId);
    final headers = await AccountStorage.getAuthHeaders();
    await _requireAccount(userId);
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/calendar/$userId/recipes${recipeId == null ? '' : '/$recipeId'}',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    await _requireAccount(userId);
    await AccountStorage.handle401(response.statusCode);
    if ({404, 405, 503}.contains(response.statusCode)) return null;
    if (response.statusCode != 200) {
      throw const CalendarCommandError('calendar_time_load_error');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> details({
    required int userId,
    required String action,
    required Map<String, dynamic> request,
    required String title,
    required DateTime date,
    List<CalendarFoodState> states = const [],
  }) async {
    if (!{'recipe', 'recipe-log', 'edit-item'}.contains(action) ||
        (action == 'recipe' &&
            (states.isEmpty || states.any((s) => !s.canRecipe))) ||
        (action == 'edit-item' &&
            (states.length != 1 || !states.single.canEditContents))) {
      throw const CalendarCommandError('calendar_details_unavailable');
    }
    await _run(
      userId,
      PendingCalendarMove(
        sourceDate: date,
        title: title,
        action: action,
        sourceDates: states.map((s) => s.date).toSet().toList(),
        consumedSourceDates: action == 'edit-item'
            ? states.where((s) => s.kind == 'meal').map((s) => s.date).toList()
            : [],
        request: {
          ...request,
          'operation_key': DayTimelineService.newEntryKey(userId),
        },
      ),
    );
  }

  static Future<void> bulk({
    required int userId,
    required String action,
    required String timezone,
    required List<Map<String, dynamic>> entries,
    required List<CalendarFoodState> states,
  }) async {
    if (states.isEmpty || states.any((s) => !s.canBulk)) {
      throw const CalendarCommandError('calendar_bulk_unavailable');
    }
    await _run(
      userId,
      PendingCalendarMove(
        sourceDate: states.first.date,
        sourceDates: states.map((s) => s.date).toSet().toList(),
        consumedSourceDates: states
            .where((s) => s.kind == 'meal')
            .map((s) => s.date)
            .toSet()
            .toList(),
        title: states.map((s) => s.title).join(', '),
        action: 'bulk',
        request: {
          'operation_key': DayTimelineService.newEntryKey(userId),
          'action': action,
          'timezone': timezone,
          'entries': entries,
        },
      ),
    );
  }

  static Future<void> copy({
    required int userId,
    required CalendarFoodState state,
    required List<Map<String, dynamic>> destinations,
    required String timezone,
    List<int>? itemIds,
    List<String>? itemKeys,
  }) async {
    if (!state.canCopy) {
      throw const CalendarCommandError('calendar_copy_unavailable');
    }
    await _run(
      userId,
      PendingCalendarMove(
        sourceDate: state.date,
        title: state.title,
        action: 'copy',
        request: {
          'operation_key': DayTimelineService.newEntryKey(userId),
          'source': state.source,
          'destinations': destinations,
          'timezone': timezone,
          if (itemIds != null) 'item_ids': itemIds,
          if (itemKeys != null) 'item_keys': itemKeys,
        },
      ),
    );
  }

  static Future<void> _run(int userId, PendingCalendarMove? fresh) async {
    if (!_busy.add(userId)) {
      throw const CalendarCommandError('calendar_time_pending_move');
    }
    try {
      await _requireAccount(userId);
      if (NetworkStatusService.instance.isOffline) {
        throw const CalendarCommandError('calendar_time_online');
      }
      final existing = await pending(userId);
      if (fresh != null && existing != null) {
        throw const CalendarCommandError('calendar_time_pending_move');
      }
      final move = fresh ?? existing;
      if (move == null) {
        throw const CalendarCommandError('calendar_time_reload', reload: true);
      }
      if (!{
        'copy',
        'reschedule',
        'bulk',
        'recipe',
        'recipe-log',
        'edit-item',
      }.contains(move.action)) {
        throw const FormatException('Unknown calendar command');
      }
      await _guardDates(userId, move);
      final headers = await AccountStorage.getAuthHeaders();
      await _requireAccount(userId);
      final prefs = await SharedPreferences.getInstance();
      // Persist before sending: process death/response loss must retain the key.
      if (fresh != null &&
          !await prefs.setString(_key(userId), jsonEncode(move.toJson()))) {
        throw const CalendarCommandError('calendar_time_storage_error');
      }
      if (fresh != null) changes.value++;
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/calendar/$userId/food/${move.action}',
            ),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: move.encodedRequest,
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        // These application responses definitively reject this request.
        // Transport/5xx/401 failures retain it until a successful manual retry.
        var missingFood = false;
        if (response.statusCode == 404) {
          try {
            missingFood = {
              'Food entry not found',
              'Recipe not found',
            }.contains((jsonDecode(response.body) as Map)['detail']);
          } catch (_) {
            /* A missing route/proxy response cannot resolve an earlier commit. */
          }
        }
        if ({400, 403, 409, 422}.contains(response.statusCode) || missingFood) {
          await prefs.remove(_key(userId));
          changes.value++;
          throw CalendarCommandError(
            response.statusCode == 409
                ? (move.isCopy
                      ? 'calendar_copy_conflict'
                      : 'calendar_time_conflict')
                : 'calendar_time_rejected',
            reload: true,
          );
        }
        if (await AccountStorage.getUserId() == userId) {
          await AccountStorage.handle401(response.statusCode);
        }
        throw const CalendarCommandError('calendar_time_uncertain');
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (result['status'] != 'committed' ||
          result['operation_key'] != move.request['operation_key']) {
        throw const CalendarCommandError('calendar_time_uncertain');
      }
      // Once committed, local housekeeping cannot turn success into save failure.
      final consumedDates = move.action == 'recipe'
          ? <DateTime>[]
          : move.action == 'edit-item'
          ? move.consumedSourceDates
          : move.action == 'recipe-log'
          ? move.destinations
                .where((d) => d['expected_status'] == 'logged')
                .map((d) => DateTime.parse(d['scheduled_date'] as String))
                .toList()
          : move.isBulk
          ? _bulkConsumedDates(move)
          : move.isCopy
          ? move.destinations
                .where((d) => d['expected_status'] == 'logged')
                .map((d) => DateTime.parse(d['scheduled_date'] as String))
                .toList()
          : (move.kind == 'meal'
                ? [move.sourceDate, move.destinationDate]
                : <DateTime>[]);
      if (consumedDates.isNotEmpty) {
        await CalendarDietRefresh.afterConsumedChange(
          userId: userId,
          dates: consumedDates,
        );
      }
      try {
        await prefs.remove(_key(userId));
        changes.value++;
      } catch (_) {
        debugPrint('Calendar saved; retry receipt cleanup failed.');
      }
    } finally {
      _busy.remove(userId);
    }
  }

  static List<DateTime> _bulkConsumedDates(PendingCalendarMove move) {
    final action = move.request['action'];
    if (action == 'copy') {
      return move.destinations
          .where((d) => d['expected_status'] == 'logged')
          .map((d) => DateTime.parse(d['scheduled_date'] as String))
          .toList();
    }
    final hasConsumed = (move.request['entries'] as List).any(
      (e) => e['source']['kind'] == 'meal',
    );
    if (!hasConsumed) return [];
    final entries = move.request['entries'] as List;
    return [
      ...move.consumedSourceDates,
      if (action == 'reschedule')
        ...entries
            .where((e) => e['source']['kind'] == 'meal')
            .expand((e) => e['destinations'] as List)
            .map((d) => DateTime.parse(d['scheduled_date'] as String)),
    ];
  }
}
