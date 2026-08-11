enum TaqaIntroModule {
  dashboard,
  diet,
  training,
  community,
  clientCoach,
  expertCoach,
}

extension TaqaIntroModuleDetails on TaqaIntroModule {
  String get storageKey => switch (this) {
    TaqaIntroModule.clientCoach => 'client_coach',
    TaqaIntroModule.expertCoach => 'expert_coach',
    _ => name,
  };

  String get titleKey => switch (this) {
    TaqaIntroModule.clientCoach => 'taqa_tutorial_client_coach_title',
    TaqaIntroModule.expertCoach => 'taqa_tutorial_expert_coach_title',
    _ => 'taqa_tutorial_${name}_title',
  };

  String get descriptionKey => switch (this) {
    TaqaIntroModule.clientCoach => 'taqa_tutorial_client_coach_sub',
    TaqaIntroModule.expertCoach => 'taqa_tutorial_expert_coach_sub',
    _ => 'taqa_tutorial_${name}_sub',
  };

  String get iconAssetPath => switch (this) {
    TaqaIntroModule.dashboard => 'assets/icons/Home.svg',
    TaqaIntroModule.diet => 'assets/icons/Diet.svg',
    TaqaIntroModule.training => 'assets/icons/Exercise.svg',
    TaqaIntroModule.community => 'assets/icons/Community.svg',
    TaqaIntroModule.clientCoach => 'assets/icons/Trainer.svg',
    TaqaIntroModule.expertCoach => 'assets/icons/Trainer.svg',
  };
}
