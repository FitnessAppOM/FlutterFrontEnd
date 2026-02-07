import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';

/// Stores the last calendar date (YYYY-MM-DD) when the user completed at least one exercise.
/// Used by the diet page to auto-set "training day" and lock "rest day" when the user trained today.
class TrainingCompletionStorage {
  static const _keyPrefix = 'exercise_completed_date';

  static String _dateToString(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Call when the user finishes an exercise (today). Persists the current date.
  static Future<void> recordExerciseCompletedToday() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}_u$userId';
    await sp.setString(key, _dateToString(DateTime.now()));
  }

  /// Returns true if the user completed at least one exercise on the given calendar date.
  /// Used by diet page: if viewing today and this returns true, lock to "training day".
  static Future<bool> didCompleteExerciseOnDate(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return false;

    final sp = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}_u$userId';
    final stored = sp.getString(key);
    if (stored == null) return false;

    final storedDate = DateTime.tryParse(stored);
    if (storedDate == null) return false;

    return _sameDay(storedDate, date);
  }
}
