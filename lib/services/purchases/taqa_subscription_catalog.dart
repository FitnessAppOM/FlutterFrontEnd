/// Store product and legal-link configuration for Taqa Fitness subscriptions.
///
/// The defaults are the product identifiers intended for App Store Connect.
/// They can be overridden for another App Store Connect environment with the
/// corresponding `--dart-define` values at build time.
class TaqaSubscriptionPlan {
  const TaqaSubscriptionPlan({
    required this.productId,
    required this.title,
    required this.periodLabel,
  });

  final String productId;
  final String title;
  final String periodLabel;
}

class TaqaSubscriptionCatalog {
  TaqaSubscriptionCatalog._();

  static const monthly = TaqaSubscriptionPlan(
    productId: String.fromEnvironment(
      'TAQA_MONTHLY_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.monthly',
    ),
    title: 'Taqa Fitness Monthly',
    periodLabel: 'Monthly',
  );

  static const studentMonthly = TaqaSubscriptionPlan(
    productId: String.fromEnvironment(
      'TAQA_STUDENT_MONTHLY_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.student.monthly',
    ),
    title: 'Taqa Fitness Student Monthly',
    periodLabel: 'Monthly',
  );

  static const annual = TaqaSubscriptionPlan(
    productId: String.fromEnvironment(
      'TAQA_ANNUAL_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.annual',
    ),
    title: 'Taqa Fitness Annual',
    periodLabel: 'Annual',
  );

  static const studentAnnual = TaqaSubscriptionPlan(
    productId: String.fromEnvironment(
      'TAQA_STUDENT_ANNUAL_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.student.annual',
    ),
    title: 'Taqa Fitness Student Annual',
    periodLabel: 'Annual',
  );

  static const coachMonthly = TaqaSubscriptionPlan(
    productId: String.fromEnvironment(
      'TAQA_COACH_MONTHLY_SUBSCRIPTION_ID',
      defaultValue: 'taqa_coach_monthly',
    ),
    title: 'Taqa Coach Monthly',
    periodLabel: 'Monthly',
  );

  static const plans = <TaqaSubscriptionPlan>[
    monthly,
    studentMonthly,
    annual,
    studentAnnual,
  ];

  static const termsOfUseUrl = String.fromEnvironment(
    'TAQA_TERMS_OF_USE_URL',
    defaultValue: 'https://taqafitness.com/terms',
  );

  static const privacyPolicyUrl = String.fromEnvironment(
    'TAQA_PRIVACY_POLICY_URL',
    defaultValue: 'https://taqafitness.com/privacy',
  );
}
