DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime localToday() => dateOnly(DateTime.now());

DateTime localYesterday() => localToday().subtract(const Duration(days: 1));
