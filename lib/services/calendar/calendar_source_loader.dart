import 'package:flutter/foundation.dart';

typedef CalendarSourceFailure =
    void Function(String source, Object error, StackTrace stackTrace);

/// Isolates independent calendar reads so one unavailable source cannot make
/// the entire month unusable.
class CalendarSourceLoader {
  const CalendarSourceLoader._();

  static Future<T> load<T>({
    required String source,
    required Future<T> Function() request,
    required T fallback,
    CalendarSourceFailure? onFailure,
  }) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      if (onFailure != null) {
        onFailure(source, error, stackTrace);
      } else {
        debugPrint('Calendar source failed: $source ($error)');
      }
      return fallback;
    }
  }
}
