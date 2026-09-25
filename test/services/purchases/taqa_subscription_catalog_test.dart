import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/purchases/taqa_subscription_catalog.dart';

void main() {
  test('subscription legal links match the App Store metadata', () {
    final terms = Uri.parse(TaqaSubscriptionCatalog.termsOfUseUrl);
    final privacy = Uri.parse(TaqaSubscriptionCatalog.privacyPolicyUrl);

    expect(
      terms,
      Uri.parse(
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      ),
    );
    expect(privacy, Uri.parse('https://taqafitness.com/privacy'));
  });

  test('verified-student catalog puts student plans first', () {
    expect(TaqaSubscriptionCatalog.studentFirstPlans, [
      TaqaSubscriptionCatalog.studentMonthly,
      TaqaSubscriptionCatalog.studentAnnual,
      TaqaSubscriptionCatalog.monthly,
      TaqaSubscriptionCatalog.annual,
    ]);
  });

  test('standard catalog contains no student plans', () {
    expect(TaqaSubscriptionCatalog.standardPlans, [
      TaqaSubscriptionCatalog.monthly,
      TaqaSubscriptionCatalog.annual,
    ]);
  });

  test('student settings catalog contains only student plans', () {
    expect(TaqaSubscriptionCatalog.studentPlans, [
      TaqaSubscriptionCatalog.studentMonthly,
      TaqaSubscriptionCatalog.studentAnnual,
    ]);
  });
}
