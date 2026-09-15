enum SubscriptionTrialUnit { day, week, month, year }

class SubscriptionTrialDuration {
  const SubscriptionTrialDuration({required this.value, required this.unit})
    : assert(value > 0);

  final int value;
  final SubscriptionTrialUnit unit;

  /// Parses the single-unit ISO-8601 periods returned by Google Play, such as
  /// P7D, P1W, P1M, and P1Y. [billingCycles] accounts for repeating trial
  /// phases (for example, P1M repeated three times).
  static SubscriptionTrialDuration? tryParseGoogleBillingPeriod(
    String billingPeriod, {
    int billingCycles = 1,
  }) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(billingPeriod.trim());
    if (match == null) return null;

    final units = int.tryParse(match.group(1)!);
    if (units == null || units <= 0) return null;
    final cycles = billingCycles > 0 ? billingCycles : 1;
    final unit = switch (match.group(2)) {
      'D' => SubscriptionTrialUnit.day,
      'W' => SubscriptionTrialUnit.week,
      'M' => SubscriptionTrialUnit.month,
      'Y' => SubscriptionTrialUnit.year,
      _ => null,
    };
    if (unit == null) return null;

    return SubscriptionTrialDuration(value: units * cycles, unit: unit);
  }
}
