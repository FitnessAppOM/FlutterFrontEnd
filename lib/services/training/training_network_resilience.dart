import 'dart:async';

/// Central short timeouts so flaky/offline networks fall through to cache
/// and local queues quickly without changing successful online behavior.
class TrainingNetworkResilience {
  TrainingNetworkResilience._();

  /// In-session mutations (start / finish / weight / sets / cardio save).
  static const Duration sheetMutation = Duration(seconds: 8);

  /// Reading per-exercise set rows when opening the session sheet.
  static const Duration sheetRead = Duration(seconds: 10);

  /// Loading the active program from the API on the Train tab.
  static const Duration programFetch = Duration(seconds: 12);

  /// Completed exercise names (secondary call after program).
  static const Duration completedNamesFetch = Duration(seconds: 10);

  /// Best-effort flush of queued exercise actions before refreshing program.
  static const Duration actionQueueSync = Duration(seconds: 18);

  static Future<T> withTimeout<T>(
    Future<T> future,
    Duration timeout,
  ) =>
      future.timeout(timeout);
}
