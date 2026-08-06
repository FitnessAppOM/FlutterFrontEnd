import 'dart:io' show Platform;

/// Store product and legal-link configuration for Taqa Fitness subscriptions.
///
/// The defaults are the product identifiers intended for App Store Connect.
/// They can be overridden for another App Store Connect environment with the
/// corresponding `--dart-define` values at build time.
class TaqaSubscriptionPlan {
  const TaqaSubscriptionPlan({
    required this.appleProductId,
    this.googleProductId,
    required this.title,
    required this.periodLabel,
  });

  final String appleProductId;
  final String? googleProductId;
  final String title;
  final String periodLabel;

  String get productId =>
      Platform.isAndroid ? googleProductId ?? appleProductId : appleProductId;
}

class TaqaSubscriptionCatalog {
  TaqaSubscriptionCatalog._();

  static const monthly = TaqaSubscriptionPlan(
    appleProductId: String.fromEnvironment(
      'TAQA_MONTHLY_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.monthly',
    ),
    title: 'Taqa Fitness Monthly',
    periodLabel: 'Monthly',
  );

  static const studentMonthly = TaqaSubscriptionPlan(
    appleProductId: String.fromEnvironment(
      'TAQA_STUDENT_MONTHLY_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.student.monthly',
    ),
    title: 'Taqa Fitness Student Monthly',
    periodLabel: 'Monthly',
  );

  static const annual = TaqaSubscriptionPlan(
    appleProductId: String.fromEnvironment(
      'TAQA_ANNUAL_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.annual',
    ),
    title: 'Taqa Fitness Annual',
    periodLabel: 'Annual',
  );

  static const studentAnnual = TaqaSubscriptionPlan(
    appleProductId: String.fromEnvironment(
      'TAQA_STUDENT_ANNUAL_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.student.annual',
    ),
    title: 'Taqa Fitness Student Annual',
    periodLabel: 'Annual',
  );

  static const coachMonthly = TaqaSubscriptionPlan(
    appleProductId: String.fromEnvironment(
      'TAQA_COACH_MONTHLY_SUBSCRIPTION_ID',
      defaultValue: 'taqa_coach_monthly',
    ),
    title: 'Taqa Coach Monthly',
    periodLabel: 'Monthly',
  );

  static const coachAnnual = TaqaSubscriptionPlan(
    appleProductId: String.fromEnvironment(
      'TAQA_COACH_ANNUAL_SUBSCRIPTION_ID',
      defaultValue: 'taqa_coach_annual',
    ),
    googleProductId: String.fromEnvironment(
      'TAQA_GOOGLE_COACH_ANNUAL_SUBSCRIPTION_ID',
      defaultValue: 'com.taqa.premium.coach.annual',
    ),
    title: 'Taqa Coach Annual',
    periodLabel: 'Annual',
  );

  static const plans = <TaqaSubscriptionPlan>[
    monthly,
    studentMonthly,
    annual,
    studentAnnual,
  ];

  static const coachPlans = <TaqaSubscriptionPlan>[coachMonthly, coachAnnual];

  static const roleChangePlans = <TaqaSubscriptionPlan>[
    monthly,
    annual,
    coachMonthly,
    coachAnnual,
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
