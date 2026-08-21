import 'package:flutter/widgets.dart';

import '../../localization/app_localizations.dart';

/// Locale-safe copy shared by the foreground UI isolate and Android's
/// background training task isolate.
class TrainingNotificationCopy {
  const TrainingNotificationCopy._();

  static AppLocalizations _translations(String languageCode) =>
      AppLocalizations(Locale(languageCode == 'ar' ? 'ar' : 'en'));

  static String text(String languageCode, String key) =>
      _translations(languageCode).translate(key);

  static String setsLabel(String languageCode, int count) => text(
    languageCode,
    'training_notification_sets',
  ).replaceAll('{count}', '$count');

  static String repsLabel(String languageCode, int count) => text(
    languageCode,
    'training_notification_reps',
  ).replaceAll('{count}', '$count');

  static String title(String languageCode, String exerciseName) =>
      _translations(languageCode)
          .translate('training_notification_title')
          .replaceAll('{name}', exerciseName);

  static String timerBody(
    String languageCode, {
    required String time,
    required int sets,
    required int reps,
  }) => _translations(languageCode)
      .translate('training_notification_timer')
      .replaceAll('{time}', time)
      .replaceAll('{sets}', '$sets')
      .replaceAll('{reps}', '$reps');

  static String cardioBody(
    String languageCode, {
    required String time,
    required String distance,
    required String pace,
  }) => _translations(languageCode)
      .translate('training_notification_cardio')
      .replaceAll('{time}', time)
      .replaceAll('{distance}', distance)
      .replaceAll('{pace}', pace);
}
