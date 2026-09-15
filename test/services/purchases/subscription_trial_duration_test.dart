import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/purchases/subscription_trial_duration.dart';

void main() {
  group('SubscriptionTrialDuration.tryParseGoogleBillingPeriod', () {
    test('parses each supported Google Play unit', () {
      expectDuration('P30D', 30, SubscriptionTrialUnit.day);
      expectDuration('P1W', 1, SubscriptionTrialUnit.week);
      expectDuration('P1M', 1, SubscriptionTrialUnit.month);
      expectDuration('P1Y', 1, SubscriptionTrialUnit.year);
    });

    test('multiplies finite recurring billing cycles', () {
      final duration = SubscriptionTrialDuration.tryParseGoogleBillingPeriod(
        'P1M',
        billingCycles: 3,
      );

      expect(duration?.value, 3);
      expect(duration?.unit, SubscriptionTrialUnit.month);
    });

    test('rejects invalid and zero-length periods', () {
      expect(
        SubscriptionTrialDuration.tryParseGoogleBillingPeriod('P1M2D'),
        isNull,
      );
      expect(
        SubscriptionTrialDuration.tryParseGoogleBillingPeriod('P0M'),
        isNull,
      );
    });
  });
}

void expectDuration(String period, int value, SubscriptionTrialUnit unit) {
  final duration = SubscriptionTrialDuration.tryParseGoogleBillingPeriod(
    period,
  );
  expect(duration?.value, value);
  expect(duration?.unit, unit);
}
