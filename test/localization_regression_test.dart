import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/components/taqa_community_group_picker_sheet.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/services/training/training_notification_copy.dart';
import 'package:taqaproject/widgets/cardio/cardio_map_controls.dart';

void main() {
  final en = AppLocalizations(const Locale('en'));
  final ar = AppLocalizations(const Locale('ar'));

  test('Arabic covers the newly localized training and diet surfaces', () {
    const keys = [
      'diet_plans',
      'diet_kcal_unit',
      'diet_edit_targets_notice',
      'training_in_progress',
      'training_cardio_in_progress',
      'training_workout_in_progress',
      'training_reopen_workout',
      'training_discard_workout',
      'training_notification_channel_name',
      'training_notification_sets',
      'training_notification_reps',
      'training_notification_live',
      'training_time',
      'training_distance_unit',
      'training_pace_unit',
      'training_days_plan',
      'training_ig_sticker',
      'training_cardio_achievement',
      'community_auto_created',
      'community_report',
      'community_choose_group',
      'community_member_count_many',
      'notification_channel_name',
      'journal_notification_title',
      'journal_notification_body',
      'expert_updates_notification_title',
      'expert_updates_notification_body',
      'post_purchase_intro_dashboard_explore_title',
    ];

    for (final key in keys) {
      expect(ar.translate(key), isNot(key), reason: key);
      expect(ar.translate(key), isNot(en.translate(key)), reason: key);
    }
  });

  test('foreground activity notification copy follows the saved language', () {
    expect(TrainingNotificationCopy.title('ar', 'Squat'), contains('تدريب'));
    expect(
      TrainingNotificationCopy.timerBody('ar', time: '01:30', sets: 3, reps: 8),
      contains('المؤقت'),
    );
    expect(
      TrainingNotificationCopy.cardioBody(
        'ar',
        time: '10:00',
        distance: '2.00',
        pace: '05:00 /km',
      ),
      contains('كم'),
    );
    expect(TrainingNotificationCopy.setsLabel('ar', 4), equals('4 مجموعات'));
    expect(TrainingNotificationCopy.repsLabel('ar', 12), equals('12 تكرارات'));
    expect(
      TrainingNotificationCopy.text('ar', 'training_notification_live'),
      equals('مباشر'),
    );
  });

  testWidgets('live mapped-cardio metrics follow Arabic localization', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const Scaffold(
            body: CardioMapControls(
              alwaysShowStatBar: true,
              distanceKm: 1.25,
              steps: 1600,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الوقت'), findsOneWidget);
    expect(find.text('المسافة'), findsOneWidget);
    expect(find.text('الوتيرة'), findsOneWidget);
    expect(find.text('الخطوات'), findsOneWidget);
    expect(find.text('1.25 كم'), findsOneWidget);
    expect(find.text('--:-- د/كم'), findsOneWidget);
    expect(find.text('Distance'), findsNothing);
    expect(find.text('Pace'), findsNothing);
  });

  testWidgets('community group picker localizes copy and RTL chevron', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(
            body: TaqaCommunityGroupPickerSheet(
              selectedId: 1,
              options: const [
                TaqaCommunityGroupPickerOption(
                  id: 1,
                  name: 'Group one',
                  memberCount: 4,
                ),
                TaqaCommunityGroupPickerOption(
                  id: 2,
                  name: 'Group two',
                  memberCount: 1,
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر مجموعة'), findsOneWidget);
    expect(find.text('4 أعضاء'), findsOneWidget);
    expect(find.text('عضو واحد'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.text('CHOOSE A GROUP'), findsNothing);
  });
}
