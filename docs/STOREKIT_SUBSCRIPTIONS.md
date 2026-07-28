# StoreKit subscription setup

The subscription screen uses StoreKit through Flutter's `in_app_purchase`
package. It loads localized product titles and prices directly from the App
Store; no dollar prices are stored in the app.

## App Store Connect

Create these four auto-renewable subscriptions for bundle ID
`com.taqafitness.app`, and place all four in the same subscription group:

| Plan | Default product ID |
| --- | --- |
| Taqa Fitness Monthly Subscription | `com.taqa.premium.monthly` |
| Taqa Fitness Student Monthly Subscription | `com.taqa.premium.student.monthly` |
| Taqa Fitness Annual Subscription | `com.taqa.premium.annual` |
| Taqa Fitness Student Annual Subscription | `com.taqa.premium.student.annual` |

If App Store Connect uses different product IDs, supply them at build time:

```sh
flutter build ipa \
  --dart-define=TAQA_MONTHLY_SUBSCRIPTION_ID=your.monthly.id \
  --dart-define=TAQA_STUDENT_MONTHLY_SUBSCRIPTION_ID=your.student.monthly.id \
  --dart-define=TAQA_ANNUAL_SUBSCRIPTION_ID=your.annual.id \
  --dart-define=TAQA_STUDENT_ANNUAL_SUBSCRIPTION_ID=your.student.annual.id
```

Publish public HTTPS pages for both the Terms of Use and Privacy Policy, then
provide their URLs at build time:

```sh
--dart-define=TAQA_TERMS_OF_USE_URL=https://example.com/terms \
--dart-define=TAQA_PRIVACY_POLICY_URL=https://example.com/privacy
```

The page can be tested with a Sandbox Apple ID on a physical device or via
TestFlight. Purchases are completed through StoreKit and Restore Purchases is
available in the screen. Before using a subscription to unlock server-side or
cross-device entitlements, add App Store receipt/transaction verification on
the backend.
