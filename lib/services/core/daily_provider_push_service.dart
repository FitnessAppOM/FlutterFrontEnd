import '../fitbit/fitbit_daily_sync.dart';
import '../metrics/daily_metrics_sync.dart';
import '../strava/strava_daily_sync.dart';
import '../whoop/whoop_daily_sync.dart';

class DailyProviderPushService {
  static const int _localStartHour = 1; // 1:00 AM local device time
  static bool _inFlight = false;

  Future<void> pushIfAfterOneAmLocal({bool force = false}) async {
    if (_inFlight) return;
    if (!force && !_isAfterWindowStart(DateTime.now())) return;
    _inFlight = true;
    try {
      try {
        await DailyMetricsSync().pushIfNewDay();
      } catch (_) {}

      try {
        await WhoopDailySync().pushIfNewDay();
      } catch (_) {}

      try {
        await FitbitDailySync().pushIfNewDay();
      } catch (_) {}

      try {
        await StravaDailySync().pushIfNewDay();
      } catch (_) {}
    } finally {
      _inFlight = false;
    }
  }

  bool _isAfterWindowStart(DateTime now) => now.hour >= _localStartHour;
}

