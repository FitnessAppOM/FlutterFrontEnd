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

  /// Whether [date] is the still-accumulating "current" day from the app's
  /// point of view, so callers must fetch it live instead of reading the
  /// persisted daily-metrics row (which is never written for the in-progress
  /// day — backfill stops at yesterday).
  ///
  /// The dashboard labels "today" with [effectiveLocalDay] (a 1 AM push clock),
  /// but live providers key their data on the raw calendar day. Between
  /// midnight and 1 AM those two clocks point at different dates, so we treat
  /// the day as current when it matches *either*. Any other date is a real
  /// past day and reads from the DB as before.
  static bool isInProgressDay(DateTime date, [DateTime? now]) {
    final reference = now ?? DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final calendarToday = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    return d == effectiveLocalDay(reference) || d == calendarToday;
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
