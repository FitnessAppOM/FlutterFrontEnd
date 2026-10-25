/// Returns a date-only value in the device's local timezone.
DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Moves by civil calendar days instead of fixed 24-hour durations.
///
/// Constructing from date components prevents duplicated or skipped dates
/// when the device crosses a daylight-saving transition.
DateTime addCalendarDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

/// Counts civil calendar days without daylight-saving offsets affecting the
/// result.
int calendarDayDifference(DateTime later, DateTime earlier) {
  final laterUtc = DateTime.utc(later.year, later.month, later.day);
  final earlierUtc = DateTime.utc(earlier.year, earlier.month, earlier.day);
  return laterUtc.difference(earlierUtc).inDays;
}
