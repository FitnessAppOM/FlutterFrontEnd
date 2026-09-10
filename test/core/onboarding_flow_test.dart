import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/core/onboarding_flow.dart';

void main() {
  group('resolveOnboardingDestination', () {
    test('never allows an incomplete questionnaire past the form', () {
      expect(
        resolveOnboardingDestination(
          questionnaireDone: false,
          subscriptionRequired: true,
          isCoachAccount: false,
          trainingReady: true,
        ),
        OnboardingDestination.questionnaire,
      );
    });

    test('sends an unsubscribed client without a plan to generation', () {
      expect(
        resolveOnboardingDestination(
          questionnaireDone: true,
          subscriptionRequired: true,
          isCoachAccount: false,
          trainingReady: false,
        ),
        OnboardingDestination.trainingGeneration,
      );
    });

    test('allows payment only after client training is ready', () {
      expect(
        resolveOnboardingDestination(
          questionnaireDone: true,
          subscriptionRequired: true,
          isCoachAccount: false,
          trainingReady: true,
        ),
        OnboardingDestination.subscription,
      );
    });

    test('allows a fully entitled account into the app', () {
      expect(
        resolveOnboardingDestination(
          questionnaireDone: true,
          subscriptionRequired: false,
          isCoachAccount: false,
          trainingReady: true,
        ),
        OnboardingDestination.app,
      );
    });
  });
}
