import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_food_commands.dart';

class CalendarTimeZone {
  static bool _initialized = false;
  static void initialize() {
    if (_initialized) return;
    data.initializeTimeZones();
    _initialized = true;
  }

  static List<String> get names {
    initialize();
    return tz.timeZoneDatabase.locations.keys.toList()..sort();
  }

  static Future<String> deviceName() async {
    initialize();
    final name = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.getLocation(name); // Never guess an IANA zone from today's offset.
    return name;
  }

  static tz.TZDateTime inZone(DateTime instant, String zone) {
    initialize();
    return tz.TZDateTime.from(instant, tz.getLocation(zone));
  }

  /// Enumerate valid instants rather than letting DateTime normalize a DST gap.
  /// A fold has two candidates; the user chooses its explicit offset.
  static List<tz.TZDateTime> candidates(
    DateTime day,
    int hour,
    int minute,
    String zone,
  ) {
    initialize();
    final location = tz.getLocation(zone);
    final wall = DateTime.utc(day.year, day.month, day.day, hour, minute);
    final candidates = <tz.TZDateTime>[];
    for (final offset in location.zones.map((z) => z.offset).toSet()) {
      final candidate = tz.TZDateTime.from(
        wall.subtract(Duration(milliseconds: offset)),
        location,
      );
      if (candidate.year == day.year &&
          candidate.month == day.month &&
          candidate.day == day.day &&
          candidate.hour == hour &&
          candidate.minute == minute &&
          candidate.second == 0) {
        candidates.add(candidate);
      }
    }
    return candidates..sort();
  }

  static String offset(DateTime time) {
    final duration = time.timeZoneOffset;
    final total = duration.inMinutes.abs();
    return '${duration.isNegative ? '-' : '+'}${(total ~/ 60).toString().padLeft(2, '0')}:'
        '${(total % 60).toString().padLeft(2, '0')}';
  }

  static String timestamp(DateTime time, {bool precise = false}) =>
      '${calendarDate(time)}T'
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:'
      '${precise ? '${time.second.toString().padLeft(2, '0')}.${(time.millisecond * 1000 + time.microsecond).toString().padLeft(6, '0')}' : '00'}${offset(time)}';
}
