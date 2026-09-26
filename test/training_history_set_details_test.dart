import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/training/training_history_day_detail_page.dart';

void main() {
  testWidgets('completed exercise opens its snapshotted set details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const TrainingHistoryDayDetailPage(
            dayLabel: 'Push Day',
            completedExercises: [
              {
                'exercise_name': 'Bench Press',
                'set_rows': [
                  {
                    'set_index': 1,
                    'reps': 10,
                    'rir': 2,
                    'weight_kg': 40.0,
                    'performed_time_seconds': 45,
                    'rest_after_seconds': 60,
                  },
                  {'set_index': 2, 'reps': 8, 'rir': 1, 'weight_kg': 42.5},
                ],
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('10 Reps'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Set details'), findsOneWidget);
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('10 Reps'), findsOneWidget);
    expect(find.text('40 KG'), findsOneWidget);
    expect(find.text('RIR 2'), findsOneWidget);
    expect(find.text('Time 00:45'), findsOneWidget);
    expect(find.text('Rest 01:00'), findsOneWidget);
    expect(find.text('42.5 KG'), findsOneWidget);
  });
}
