import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';
import 'training_reset_coordinator.dart';

/// Stores the last calendar date (YYYY-MM-DD) when the user completed at least one exercise.
/// Used by the diet page to auto-set "training day" and lock "rest day" when the user trained today.
class TrainingCompletionStorage {
  static const _keyPrefix = 'exercise_completed_date';
  static const _keyDayIdPrefix = 'exercise_completed_training_day_id';
  static const _keyDayLabelPrefix = 'exercise_completed_training_day_label';
  static const _cardioDateKeyPrefix = 'cardio_completed_date';
  static const _cardioDurationKeyPrefix = 'cardio_completed_duration_seconds';

  /// Call when the user finishes an exercise (today). Persists the current date.
  static Future<void> recordExerciseCompletedToday({
    int? trainingDayId,
    String? trainingDayLabel,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}_u$userId';
    final today = await TrainingResetCoordinator.currentDayToken();
    await sp.setString(key, today);
    final dayIdKey = '${_keyDayIdPrefix}_u$userId';
    final dayLabelKey = '${_keyDayLabelPrefix}_u$userId';
    if (trainingDayId != null && trainingDayId > 0) {
      await sp.setInt(dayIdKey, trainingDayId);
    } else {
      await sp.remove(dayIdKey);
    }
    final normalizedLabel = trainingDayLabel?.trim() ?? '';
    if (normalizedLabel.isNotEmpty) {
      await sp.setString(dayLabelKey, normalizedLabel);
    } else {
      await sp.remove(dayLabelKey);
    }
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
    return stored == TrainingResetCoordinator.dateToken(date);
  }

  /// Returns the locked training day info for the given date (if any).
  /// Null means either not trained that day, or no specific day metadata stored.
  static Future<Map<String, dynamic>?> getCompletedTrainingDayForDate(
    DateTime date,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final didComplete = await didCompleteExerciseOnDate(date);
    if (!didComplete) return null;

    final sp = await SharedPreferences.getInstance();
    final dayId = sp.getInt('${_keyDayIdPrefix}_u$userId');
    final dayLabel = sp.getString('${_keyDayLabelPrefix}_u$userId');
    if ((dayId == null || dayId <= 0) &&
        (dayLabel == null || dayLabel.trim().isEmpty)) {
      return null;
    }
    return {
      if (dayId != null && dayId > 0) 'training_day_id': dayId,
      if (dayLabel != null && dayLabel.trim().isNotEmpty)
        'training_day_label': dayLabel.trim(),
    };
  }

  /// Call when user finishes a cardio session (today). Persists date and max duration for that day.
  static Future<void> recordCardioSessionToday({
    required int durationSeconds,
  }) async {
    if (durationSeconds <= 0) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final dayToken = await TrainingResetCoordinator.currentDayToken();
    final dateKey = '${_cardioDateKeyPrefix}_u$userId';
    final durationKey = '${_cardioDurationKeyPrefix}_u$userId';
    final existingDay = sp.getString(dateKey);
    final existingDuration = sp.getInt(durationKey) ?? 0;

    if (existingDay == dayToken) {
      if (durationSeconds > existingDuration) {
        await sp.setInt(durationKey, durationSeconds);
      }
      return;
    }

    await sp.setString(dateKey, dayToken);
    await sp.setInt(durationKey, durationSeconds);
  }

  /// Returns true if the user completed a cardio session with at least [minDurationMinutes]
  /// on the given calendar date.
  static Future<bool> didCompleteCardioAtLeastMinutesOnDate(
    DateTime date, {
    int minDurationMinutes = 15,
  }) async {
    if (minDurationMinutes <= 0) return true;
    final userId = await AccountStorage.getUserId();
    if (userId == null) return false;

    final sp = await SharedPreferences.getInstance();
    final dateKey = '${_cardioDateKeyPrefix}_u$userId';
    final durationKey = '${_cardioDurationKeyPrefix}_u$userId';
    final storedDate = sp.getString(dateKey);
    if (storedDate == null) return false;
    if (storedDate != TrainingResetCoordinator.dateToken(date)) return false;

    final durationSeconds = sp.getInt(durationKey) ?? 0;
    return durationSeconds >= (minDurationMinutes * 60);
  }
}
