import 'dart:async';
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
import 'package:taqaproject/screens/calendar/timeline_nutrition_header.dart';

Map<String, int> nutrients(int calories) => {
  'calories': calories,
  'protein_g': 40,
  'carbs_g': 80,
  'fat_g': 20,
};

Map<String, dynamic> summary({int calories = 2300, bool targets = true}) => {
  'live': {
    'consumed': nutrients(calories),
    'target': targets ? nutrients(2000) : null,
    'remaining': targets ? nutrients(2000 - calories) : null,
  },
  // A captured report must never replace live consumption in this header.
  'snapshot': {'consumed': nutrients(9999)},
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 42});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpHeader(
    WidgetTester tester, {
    DateTime? date,
    Locale locale = const Locale('en'),
    double textScale = 1,
    int refreshRevision = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SingleChildScrollView(
                child: TimelineNutritionHeader(
                  date: date ?? DateTime(2026, 1, 5),
                  refreshRevision: refreshRevision,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'uses live totals for the selected date and shows over-target progress',
    (tester) async {
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await pumpHeader(tester);
          await tester.pumpAndSettle();
          expect(find.textContaining('2,300'), findsOneWidget);
          expect(find.textContaining('9,999'), findsNothing);
          expect(find.text('300 kcal over target'), findsOneWidget);
          final calories = find.byKey(
            const ValueKey('timeline-nutrition-calories'),
          );
          expect(
            tester
                .widget<LinearProgressIndicator>(
                  find.descendant(
                    of: calories,
                    matching: find.byType(LinearProgressIndicator),
                  ),
                )
                .value,
            1,
          );
          expect(requests, hasLength(1));
          expect(requests.single.method, 'GET');
          expect(requests.single.url.path, endsWith('/diet/day-summary/42'));
          expect(requests.single.url.queryParameters, {
            'meal_date': '2026-01-05',
          });
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(summary()), 200);
        }),
      );
    },
  );

  testWidgets(
    'no targets still shows consumed nutrition without invented goals',
    (tester) async {
      await http.runWithClient(
        () async {
          await pumpHeader(tester);
          await tester.pumpAndSettle();
          expect(find.text('No diet targets yet.'), findsOneWidget);
          expect(find.textContaining('2,300'), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(find.textContaining('Remaining:'), findsNothing);
        },
        () => MockClient(
          (_) async => http.Response(jsonEncode(summary(targets: false)), 200),
        ),
      );
    },
  );

  testWidgets(
    'malformed nutrition is unavailable, not zero; retry can recover',
    (tester) async {
      var calls = 0;
      await http.runWithClient(
        () async {
          await pumpHeader(tester);
          await tester.pumpAndSettle();
          expect(
            find.textContaining("Couldn't load nutrition"),
            findsOneWidget,
          );
          expect(find.textContaining('Consumed:'), findsNothing);
          await tester.tap(find.byType(TextButton));
          await tester.pumpAndSettle();
          expect(find.textContaining('2,300'), findsOneWidget);
          expect(calls, 2);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode(++calls == 1 ? {'live': {}} : summary()),
            200,
          ),
        ),
      );
    },
  );

  testWidgets(
    'late response from a previous day cannot replace the selected day',
    (tester) async {
      final first = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await pumpHeader(tester);
          await pumpHeader(tester, date: DateTime(2026, 1, 6));
          await tester.pumpAndSettle();
          expect(find.textContaining('1,200'), findsOneWidget);
          first.complete(http.Response(jsonEncode(summary()), 200));
          await tester.pumpAndSettle();
          expect(find.textContaining('1,200'), findsOneWidget);
          expect(find.textContaining('2,300'), findsNothing);
        },
        () => MockClient((request) async {
          return request.url.queryParameters['meal_date'] == '2026-01-05'
              ? first.future
              : http.Response(jsonEncode(summary(calories: 1200)), 200);
        }),
      );
    },
  );

  testWidgets('refresh of the same date reloads live nutrition', (
    tester,
  ) async {
    var calls = 0;
    await http.runWithClient(
      () async {
        await pumpHeader(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('1,200'), findsOneWidget);
        await pumpHeader(tester, refreshRevision: 1);
        await tester.pumpAndSettle();
        expect(find.textContaining('1,800'), findsOneWidget);
        expect(find.textContaining('1,200'), findsNothing);
        expect(calls, 2);
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode(summary(calories: ++calls == 1 ? 1200 : 1800)),
          200,
        ),
      ),
    );
  });

  testWidgets('slow or failed nutrition never hides the loaded timeline', (
    tester,
  ) async {
    final nutrition = Completer<http.Response>();
    await http.runWithClient(
      () async {
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
              home: DayTimelinePage(
                date: DateTime(2026, 1, 5),
                program: const {},
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.scrollUntilVisible(
          find.text('LOG FOOD'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('LOG FOOD'), findsOneWidget);
        expect(find.text('LOG SLEEP'), findsOneWidget);
        nutrition.complete(http.Response('{}', 500));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining("Couldn't load nutrition"),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining("Couldn't load nutrition"), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('LOG FOOD'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('LOG FOOD'), findsOneWidget);
        expect(find.text("Couldn't load this day's timeline."), findsNothing);
      },
      () => MockClient((request) async {
        if (request.url.path.contains('/diet/day-summary/')) {
          return nutrition.future;
        }
        if (request.url.path.endsWith('/sessions') ||
            request.url.path.endsWith('/recipes')) {
          return http.Response('{}', 404);
        }
        return http.Response(
          jsonEncode({
            'entry_date': '2026-01-05',
            'daily_summary': null,
            'events': [],
          }),
          200,
        );
      }),
    );
  });

  testWidgets('Arabic at large text size fits a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(
      () async {
        await pumpHeader(tester, locale: const Locale('ar'), textScale: 2);
        await tester.pumpAndSettle();
        expect(find.text('التغذية اليومية'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((_) async => http.Response(jsonEncode(summary()), 200)),
    );
  });
}
