enum OnboardingDestination {
  questionnaire,
  trainingGeneration,
  subscription,
  app,
}

OnboardingDestination resolveOnboardingDestination({
  required bool questionnaireDone,
  required bool subscriptionRequired,
  required bool isCoachAccount,
  required bool trainingReady,
}) {
  if (!questionnaireDone) return OnboardingDestination.questionnaire;
  if (!subscriptionRequired) return OnboardingDestination.app;
  if (!isCoachAccount && !trainingReady) {
    return OnboardingDestination.trainingGeneration;
  }
  return OnboardingDestination.subscription;
}
