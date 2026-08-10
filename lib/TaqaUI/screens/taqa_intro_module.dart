enum TaqaIntroModule { dashboard, diet, training, community, coach }

extension TaqaIntroModuleDetails on TaqaIntroModule {
  String get storageKey => name;

  String get titleKey => 'taqa_tutorial_${name}_title';

  String get descriptionKey => 'taqa_tutorial_${name}_sub';

  String get iconAssetPath => switch (this) {
    TaqaIntroModule.dashboard => 'assets/icons/Home.svg',
    TaqaIntroModule.diet => 'assets/icons/Diet.svg',
    TaqaIntroModule.training => 'assets/icons/Exercise.svg',
    TaqaIntroModule.community => 'assets/icons/Community.svg',
    TaqaIntroModule.coach => 'assets/icons/Trainer.svg',
  };
}
