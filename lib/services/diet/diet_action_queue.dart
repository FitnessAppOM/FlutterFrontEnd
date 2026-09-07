import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../../core/user_friendly_error.dart';
import '../core/network_status_service.dart';
import '../core/offline_queue_signal.dart';
import 'diet_meals_storage.dart';

enum DietActionType { manualEntry, updateMeal, deleteMeal, deleteMealItem }

/// A deliberately small offline queue for mutations that target existing
/// server-side meal IDs. Creating meal slots, search, photos, favourites and AI
/// operations remain online-only because replaying them is not safely mappable.
class DietActionQueue {
  DietActionQueue._();

  static const _prefix = 'diet_action_queue';
  static bool _syncing = false;

  static String _key(int userId) => '${_prefix}_u$userId';

  static String _dateParam(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static Future<List<Map<String, dynamic>>> _load(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(userId));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> enqueue({
    required int userId,
    required DietActionType type,
    required Map<String, dynamic> body,
    required DateTime mealDate,
    int? trainingDayId,
  }) async {
    final queue = await _load(userId);
    final mealId = body['meal_id'];
    if (type == DietActionType.deleteMeal) {
      queue.removeWhere((action) {
        final actionBody = action['body'];
        return actionBody is Map && actionBody['meal_id'] == mealId;
      });
    } else if (type == DietActionType.deleteMealItem) {
      queue.removeWhere((action) {
        final actionBody = action['body'];
        return action['type'] == type.name &&
            actionBody is Map &&
            actionBody['meal_item_id'] == body['meal_item_id'];
      });
    }
    queue.add({
      'id': '${DateTime.now().microsecondsSinceEpoch}_${type.name}',
      'type': type.name,
      'body': Map<String, dynamic>.from(body),
      'meal_date': _dateParam(mealDate),
      if (trainingDayId != null) 'training_day_id': trainingDayId,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (queue.length > 100) queue.removeRange(0, queue.length - 100);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(userId), jsonEncode(queue));
    OfflineQueueSignal.notifyChanged();
  }

  static Future<int> pendingCount() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return 0;
    return (await _load(userId)).length;
  }

  static Future<http.Response> _send(
    int userId,
    Map<String, dynamic> action,
  ) async {
    final rawBody = action['body'];
    if (rawBody is! Map) throw const FormatException('Invalid diet action');
    final body = Map<String, dynamic>.from(rawBody);
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    switch (action['type']) {
      case 'manualEntry':
        return http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/diet/meals/$userId/items/manual'),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 10));
      case 'updateMeal':
        return http
            .patch(
              Uri.parse('${ApiConfig.baseUrl}/diet/meals/$userId'),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 10));
      case 'deleteMeal':
        final url = Uri.parse('${ApiConfig.baseUrl}/diet/meals/$userId')
            .replace(
              queryParameters: {
                'meal_id': body['meal_id'].toString(),
                if (action['training_day_id'] != null)
                  'training_day_id': action['training_day_id'].toString(),
              },
            );
        return http
            .delete(url, headers: await AccountStorage.getAuthHeaders())
            .timeout(const Duration(seconds: 10));
      case 'deleteMealItem':
        final itemId = body['meal_item_id'];
        var response = await http
            .delete(
              Uri.parse('${ApiConfig.baseUrl}/diet/meals/$userId/$itemId'),
              headers: await AccountStorage.getAuthHeaders(),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 404) {
          response = await http
              .delete(
                Uri.parse(
                  '${ApiConfig.baseUrl}/diet/meals/$userId/items/$itemId',
                ),
                headers: await AccountStorage.getAuthHeaders(),
              )
              .timeout(const Duration(seconds: 10));
        }
        return response;
      default:
        throw const FormatException('Unknown diet action');
    }
  }

  static Future<void> syncQueue() async {
    if (_syncing) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    _syncing = true;
    try {
      final queue = await _load(userId);
      if (queue.isEmpty) return;
      final failed = <Map<String, dynamic>>[];
      final refreshKeys = <String>{};
      var networkUnavailable = false;

      for (final action in queue) {
        if (networkUnavailable) {
          failed.add(action);
          continue;
        }
        try {
          final response = await _send(userId, action);
          await AccountStorage.handle401(response.statusCode);
          NetworkStatusService.instance.reportServerReached();
          final isDelete = action['type'] == DietActionType.deleteMeal.name ||
              action['type'] == DietActionType.deleteMealItem.name;
          if ((response.statusCode >= 200 && response.statusCode < 300) ||
              (isDelete && response.statusCode == 404)) {
            refreshKeys.add(
              '${action['meal_date']}|${action['training_day_id'] ?? ''}',
            );
          } else {
            failed.add(action);
          }
        } catch (error) {
          if (isNetworkError(error)) {
            networkUnavailable = true;
            NetworkStatusService.instance.reportNetworkFailure(error);
          }
          failed.add(action);
        }
      }

      final preferences = await SharedPreferences.getInstance();
      if (failed.isEmpty) {
        await preferences.remove(_key(userId));
      } else {
        await preferences.setString(_key(userId), jsonEncode(failed));
      }
      OfflineQueueSignal.notifyChanged();

      if (!networkUnavailable) {
        for (final key in refreshKeys) {
          await _refreshCachedDay(userId, key);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _refreshCachedDay(int userId, String key) async {
    final parts = key.split('|');
    final date = DateTime.tryParse(parts.first);
    if (date == null) return;
    final trainingDayId = parts.length > 1 && parts[1].isNotEmpty
        ? int.tryParse(parts[1])
        : null;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/diet/meals/$userId').replace(
        queryParameters: {
          'meal_date': _dateParam(date),
          'auto_open': 'false',
          if (trainingDayId != null)
            'training_day_id': trainingDayId.toString(),
        },
      );
      final response = await http
          .get(url, headers: await AccountStorage.getAuthHeaders())
          .timeout(const Duration(seconds: 10));
      await AccountStorage.handle401(response.statusCode);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          await DietMealsStorage.saveMealsForDate(
            date,
            Map<String, dynamic>.from(decoded),
            trainingDayId: trainingDayId,
          );
        }
      }
    } catch (_) {
      // The mutation is already synced. A normal screen refresh can repair the
      // cache later, so a cache-refresh failure must not requeue the mutation.
    }
  }

  static Future<void> projectManualEntry({
    required DateTime mealDate,
    required int mealId,
    required List<Map<String, dynamic>> ingredients,
    String? mealName,
    int? trainingDayId,
  }) async {
    await DietMealsStorage.mutateMealsForDate(
      mealDate,
      (data) {
        final meal = _findMeal(data, mealId);
        if (meal == null) return data;
        if (mealName != null && mealName.trim().isNotEmpty) {
          meal['title'] = mealName.trim();
        }
        final items = _mutableList(meal, 'items');
        var sequence = 0;
        for (final ingredient in ingredients) {
          items.add({
            'id': -(DateTime.now().microsecondsSinceEpoch + sequence++),
            'meal_id': mealId,
            'source': 'manual',
            'item_name': ingredient['ingredient_name']?.toString() ?? '',
            'grams': ingredient['grams'],
            'calories': _asInt(ingredient['calories']),
            'protein_g': _asInt(ingredient['protein_g']),
            'carbs_g': _asInt(ingredient['carbs_g']),
            'fat_g': _asInt(ingredient['fat_g']),
            'food_id': ingredient['food_id'],
            'ingredients': <dynamic>[],
            'offline_pending': true,
          });
        }
        _recalculate(data);
        return data;
      },
      trainingDayId: trainingDayId,
    );
  }

  static Future<void> projectMealUpdate({
    required DateTime mealDate,
    required int mealId,
    String? title,
    String? notes,
    int? trainingDayId,
  }) async {
    await DietMealsStorage.mutateMealsForDate(
      mealDate,
      (data) {
        final meal = _findMeal(data, mealId);
        if (meal != null) {
          if (title != null) meal['title'] = title;
          if (notes != null) meal['notes'] = notes;
          meal['offline_pending'] = true;
        }
        return data;
      },
      trainingDayId: trainingDayId,
    );
  }

  static Future<void> projectDeleteMeal({
    required DateTime mealDate,
    required int mealId,
    int? trainingDayId,
  }) async {
    await DietMealsStorage.mutateMealsForDate(
      mealDate,
      (data) {
        _mutableList(data, 'meals').removeWhere(
          (meal) => meal is Map && _asInt(meal['meal_id']) == mealId,
        );
        _recalculate(data);
        return data;
      },
      trainingDayId: trainingDayId,
    );
  }

  static Future<void> projectDeleteMealItem({
    required DateTime mealDate,
    required int mealItemId,
    int? trainingDayId,
  }) async {
    await DietMealsStorage.mutateMealsForDate(
      mealDate,
      (data) {
        for (final rawMeal in _mutableList(data, 'meals')) {
          if (rawMeal is! Map) continue;
          _mutableList(rawMeal, 'items').removeWhere(
            (item) => item is Map && _asInt(item['id']) == mealItemId,
          );
        }
        _recalculate(data);
        return data;
      },
      trainingDayId: trainingDayId,
    );
  }

  static Map<String, dynamic>? _findMeal(
    Map<String, dynamic> data,
    int mealId,
  ) {
    for (final rawMeal in _mutableList(data, 'meals')) {
      if (rawMeal is Map && _asInt(rawMeal['meal_id']) == mealId) {
        return rawMeal.cast<String, dynamic>();
      }
    }
    return null;
  }

  static List<dynamic> _mutableList(Map data, String key) {
    final value = data[key];
    if (value is List) return value;
    final list = <dynamic>[];
    data[key] = list;
    return list;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static void _recalculate(Map<String, dynamic> data) {
    final consumed = {
      'calories': 0,
      'protein_g': 0,
      'carbs_g': 0,
      'fat_g': 0,
    };
    for (final rawMeal in _mutableList(data, 'meals')) {
      if (rawMeal is! Map) continue;
      final totals = {
        'calories': 0,
        'protein_g': 0,
        'carbs_g': 0,
        'fat_g': 0,
      };
      for (final rawItem in _mutableList(rawMeal, 'items')) {
        if (rawItem is! Map) continue;
        for (final key in totals.keys) {
          totals[key] = totals[key]! + _asInt(rawItem[key]);
        }
      }
      rawMeal['totals'] = totals;
      for (final key in consumed.keys) {
        consumed[key] = consumed[key]! + totals[key]!;
      }
    }

    final summary = data['day_summary'];
    if (summary is! Map) return;
    final live = summary['live'] is Map ? summary['live'] as Map : summary;
    live['consumed'] = consumed;
    final target = live['target'];
    if (target is Map) {
      live['remaining'] = {
        for (final key in consumed.keys)
          key: _asInt(target[key]) - consumed[key]!,
      };
    }
  }
}
