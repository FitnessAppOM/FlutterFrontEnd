import '../fitbit/fitbit_daily_sync.dart';
import '../metrics/daily_metrics_sync.dart';
import '../whoop/whoop_daily_sync.dart';

class DailyProviderPushService {
  static const int localStartHour = 1; // 1:00 AM local device time
  static bool _inFlight = false;

  static DateTime effectiveLocalDay([DateTime? now]) {
    final reference = (now ?? DateTime.now()).subtract(
      const Duration(hours: localStartHour),
    );
    return DateTime(reference.year, reference.month, reference.day);
  }

  Future<void> pushIfAfterOneAmLocal({bool force = false}) async {
    if (_inFlight) return;
    if (!force && !_isAfterWindowStart(DateTime.now())) return;
    _inFlight = true;
    try {
      try {
        await DailyMetricsSync().pushIfNewDay();
      } catch (e) {
        // ignore: avoid_print
        print("DailyProviderPushService: daily metrics sync failed: $e");
      }

      try {
        await WhoopDailySync().pushIfNewDay();
      } catch (e) {
        // ignore: avoid_print
        print("DailyProviderPushService: whoop sync failed: $e");
      }

      try {
        await FitbitDailySync().pushIfNewDay();
      } catch (e) {
        // ignore: avoid_print
        print("DailyProviderPushService: fitbit sync failed: $e");
      }
    } finally {
      _inFlight = false;
    }
  }

  bool _isAfterWindowStart(DateTime now) => now.hour >= localStartHour;
}
