import 'package:flutter/foundation.dart';

import '../../core/account_storage.dart';
import '../diet/diet_action_queue.dart';
import '../diet/diet_day_summary_storage.dart';
import '../diet/diet_meals_storage.dart';

/// Local follow-up to an already committed consumed-food mutation.
/// Cache/refresh failures must never be reported as a failed server write.
class CalendarDietRefresh {
  static Future<void> afterConsumedChange({
    required int userId,
    required Iterable<DateTime> dates,
  }) async {
    try {
      final days = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
      for (final date in days) {
        // Preserve optimistic offline edits until their existing queue replays.
        if (await DietActionQueue.hasPendingForDate(userId, date)) continue;
        await DietMealsStorage.invalidateDate(userId, date);
        await DietDaySummaryStorage.invalidateDate(userId, date);
      }
    } catch (_) {
      debugPrint('Calendar saved; local diet cache invalidation failed.');
    }
    try {
      if (await AccountStorage.getUserId() == userId) {
        AccountStorage.notifyDietChanged();
      }
    } catch (_) {
      debugPrint('Calendar saved; diet refresh notification failed.');
    }
  }
}
