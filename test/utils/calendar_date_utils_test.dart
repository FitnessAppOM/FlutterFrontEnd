import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/utils/calendar_date_utils.dart';

void main() {
  test('calendar-day iteration never duplicates dates', () {
    final start = DateTime(2026, 10, 24);
    final dates = List.generate(5, (index) => addCalendarDays(start, index));

    expect(
      dates.map((date) => '${date.year}-${date.month}-${date.day}').toList(),
      ['2026-10-24', '2026-10-25', '2026-10-26', '2026-10-27', '2026-10-28'],
    );
  });

  test('calendar-day difference ignores elapsed-hour changes', () {
    expect(
      calendarDayDifference(DateTime(2026, 10, 26), DateTime(2026, 10, 24)),
      2,
    );
  });
}
