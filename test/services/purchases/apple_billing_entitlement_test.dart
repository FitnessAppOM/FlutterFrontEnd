import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/purchases/apple_billing_service.dart';

void main() {
  test('active access without a store subscription is complimentary', () {
    const entitlement = AppleBillingEntitlement(active: true);

    expect(entitlement.isComplimentaryAccess, isTrue);
    expect(entitlement.hasStoreSubscription, isFalse);
  });

  test('store subscription is not classified as complimentary', () {
    const entitlement = AppleBillingEntitlement(
      active: true,
      platform: 'apple',
      productId: 'com.taqa.premium.monthly',
      autoRenew: true,
    );

    expect(entitlement.isComplimentaryAccess, isFalse);
    expect(entitlement.hasStoreSubscription, isTrue);
  });

  test('subscription list also proves store-managed access', () {
    const entitlement = AppleBillingEntitlement(
      active: true,
      subscriptions: [
        StoreBillingSubscription(
          platform: 'google',
          productId: 'taqa_premium_monthly',
        ),
      ],
    );

    expect(entitlement.isComplimentaryAccess, isFalse);
    expect(entitlement.hasStoreSubscription, isTrue);
  });
}
