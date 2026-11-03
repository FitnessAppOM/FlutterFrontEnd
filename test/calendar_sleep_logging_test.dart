import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/calendar/day_timeline_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 42});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpDay(WidgetTester tester, DateTime day) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DayTimelinePage(date: day, program: const {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final fails in [false, true]) {
    testWidgets(
      fails
          ? 'failed sleep save does not persist a local override'
          : 'sleep is saved to the selected past date and can be edited',
      (tester) async {
        final writes = <Map<String, dynamic>>[];
        Map<String, dynamic> summary = {'steps': 9000};
        await http.runWithClient(
          () async {
            await pumpDay(tester, DateTime(2026, 1, 5));
            await tester.tap(find.text('LOG SLEEP'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), '7.5');
            await tester.tap(find.text('SAVE'));
            await tester.pumpAndSettle();

            expect(writes, [
              {
                'user_id': 42,
                'entry_date': '2026-01-05',
                'sleep_hours': 7.5,
                'sleep_minutes_asleep': 450,
              },
            ]);
            final prefs = await SharedPreferences.getInstance();
            final stored = prefs.getString('manual_sleep_entries_u42');
            if (fails) {
              expect(stored, isNull);
              expect(
                find.text("Couldn't save sleep. Please try again."),
                findsOneWidget,
              );
            } else {
              expect(jsonDecode(stored!), {'2026-01-05': 7.5});
              expect(find.text('EDIT SLEEP'), findsOneWidget);
              expect(find.textContaining('9,000'), findsOneWidget);
              await tester.tap(find.text('EDIT SLEEP'));
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<TextField>(find.byType(TextField))
                    .controller!
                    .text,
                '7.50',
              );
              await tester.enterText(find.byType(TextField), '8');
              await tester.tap(find.text('SAVE'));
              await tester.pumpAndSettle();
              expect(writes, hasLength(2));
              expect(writes.last['entry_date'], '2026-01-05');
              expect(writes.last['sleep_minutes_asleep'], 480);
              expect(jsonDecode(prefs.getString('manual_sleep_entries_u42')!), {
                '2026-01-05': 8.0,
              });
            }
            await tester.pump(const Duration(seconds: 4));
            await tester.pumpAndSettle();
          },
          () => MockClient((request) async {
            if (request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              writes.add(body);
              if (fails) return http.Response('{}', 500);
              summary = {...summary, ...body};
              return http.Response('{}', 200);
            }
            return http.Response(
              jsonEncode({
                'entry_date': '2026-01-05',
                'daily_summary': summary,
                'events': [],
              }),
              200,
            );
          }),
        );
      },
    );
  }

  testWidgets('future dates do not offer sleep logging', (tester) async {
    final day = DateTime.now().add(const Duration(days: 2));
    await http.runWithClient(
      () async {
        await pumpDay(tester, day);
        expect(find.text('LOG SLEEP'), findsNothing);
        expect(find.text('EDIT SLEEP'), findsNothing);
        expect(find.text('LOG FOOD'), findsOneWidget);
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'entry_date': day.toIso8601String().split('T').first,
            'daily_summary': null,
            'events': [],
          }),
          200,
        ),
      ),
    );
  });

  testWidgets('invalid durations stay in the dialog and cancel does not save', (
    tester,
  ) async {
    var writes = 0;
    await http.runWithClient(
      () async {
        await pumpDay(tester, DateTime.now());
        await tester.tap(find.text('LOG SLEEP'));
        await tester.pumpAndSettle();
        for (final input in ['0', '25', 'NaN', '-1']) {
          await tester.enterText(find.byType(TextField), input);
          await tester.tap(find.text('SAVE'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Enter a sleep duration from 1 minute to 24 hours, in hours (e.g. 7.5).',
            ),
            findsOneWidget,
          );
          expect(writes, 0);
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(writes, 0);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') writes++;
        return http.Response(
          jsonEncode({
            'entry_date': DateTime.now().toIso8601String().split('T').first,
            'daily_summary': null,
            'events': [],
          }),
          200,
        );
      }),
    );
  });
}
