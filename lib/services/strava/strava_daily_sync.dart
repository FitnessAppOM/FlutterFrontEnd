import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_storage.dart';
import 'strava_service.dart';

class StravaDailySync {
  static const _lastPushKey = "strava_daily_last_push_date";
  static bool _syncInFlight = false;

  Future<void> pushIfNewDay() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId == 0) return;
      final linkedHint = await AccountStorage.getStravaLinked();
      if (linkedHint != true) return;

      final sp = await SharedPreferences.getInstance();
      final lastKey = _userScopedKey(userId);
      final todayKey = _dateKey(DateTime.now());
      final last = sp.getString(lastKey);
      if (last == todayKey) return;

      final status = await StravaService().fetchStatus();
      final linked = status["linked"] == true;
      await AccountStorage.setStravaLinked(linked);
      if (linked) {
        // Prime latest activity data once per day for faster first widget load.
        await StravaService().fetchActivitiesOverview(
          page: 1,
          perPage: 1,
          forceRefresh: true,
        );
      }

      await sp.setString(lastKey, todayKey);
    } finally {
      _syncInFlight = false;
    }
  }

  String _userScopedKey(int userId) => "${_lastPushKey}_$userId";

  String _dateKey(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
}

