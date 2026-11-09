import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/calendar/calendar_health_sheet.dart';
import 'package:taqaproject/screens/calendar/calendar_health_banner.dart';
import 'package:taqaproject/screens/calendar/day_timeline_page.dart';
import 'package:taqaproject/services/calendar/calendar_health_api.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/screens/calendar/calendar_page.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'package:taqaproject/TaqaUI/components/taqa_timeline.dart';
import 'services/calendar/calendar_health_api_test.dart'
    show healthSession, healthDay, healthCommitted;

Widget healthApp(Widget child, {bool arabic = false}) => ScreenUtilInit(
  designSize: TaqaUiScale.designSize,
  builder: (_, _) => MaterialApp(
    locale: Locale(arabic ? 'ar' : 'en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(arabic ? 1.8 : 1)),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 42});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => 'UTC',
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        ),
  );
  Future<void> pump(
    WidgetTester tester, {
    String kind = 'activity',
    Map<String, dynamic>? session,
    bool arabic = false,
  }) async {
    await tester.pumpWidget(
      healthApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCalendarHealth(
                context,
                userId: 42,
                date: DateTime(2026, 1, 5),
                kind: kind,
                session: session,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        arabic: arabic,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final scrollable = find
        .descendant(
          of: find.byType(CalendarHealthSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: scrollable,
        maxScrolls: 35,
      );
    }
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    if (target.hitTestable().evaluate().isEmpty) {
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'activity saves distance and completed interval without a workout reference',
    (tester) async {
      Map? sent;
      await http.runWithClient(
        () async {
          await pump(tester);
          expect(find.text('Timezone'), findsNothing);
          await tester.ensureVisible(find.byType(TextField));
          await tester.enterText(find.byType(TextField), '2.125');
          await tap(tester, 'Save session');
          expect(find.byType(CalendarHealthSheet), findsNothing);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(jsonEncode(healthDay()), 200);
          }
          sent = jsonDecode(r.body) as Map;
          return healthCommitted(r);
        }),
      );
      expect(sent!['action'], 'create');
      expect(sent!['session']['distance_km'], '2.125');
      expect(sent!['session']['activity_kind'], 'walk');
      expect(sent!['session']['timezone'], 'UTC');
      expect(sent!['session'].containsKey('program_id'), false);
    },
  );
  testWidgets('sleep uses previous bedtime and selected wake date', (
    tester,
  ) async {
    Map? sent;
    await http.runWithClient(
      () async {
        await pump(tester, kind: 'sleep');
        await tap(tester, 'Save session');
      },
      () => MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(jsonEncode(healthDay()), 200);
        }
        sent = jsonDecode(r.body) as Map;
        return healthCommitted(r);
      }),
    );
    expect(sent!['session']['entry_date'], '2026-01-05');
    expect(sent!['session']['started_at'], '2026-01-04T23:00:00+00:00');
    expect(sent!['session']['ended_at'], '2026-01-05T07:00:00+00:00');
    expect(
      (await SharedPreferences.getInstance()).getString(
        'manual_sleep_entries_u42',
      ),
      isNull,
    );
  });
  testWidgets('edit loads latest revision and delete requires confirmation', (
    tester,
  ) async {
    Map? sent;
    final original = healthSession();
    final fresh = {
      ...original,
      'source': {'id': 9, 'revision': 5},
    };
    await http.runWithClient(
      () async {
        await pump(tester, kind: 'sleep', session: original);
        await tap(tester, 'Delete session');
        expect(sent, isNull);
        await tap(tester, 'Cancel');
        expect(sent, isNull);
        await tap(tester, 'Delete session');
        await tap(tester, 'Delete session');
      },
      () => MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(jsonEncode(healthDay(sessions: [fresh])), 200);
        }
        sent = jsonDecode(r.body) as Map;
        return healthCommitted(r);
      }),
    );
    expect(sent!['action'], 'delete');
    expect(sent!['source'], {'id': 9, 'revision': 5});
    expect(sent!.containsKey('session'), false);
  });
  testWidgets(
    'failed phone detection shows the fallback and never silently saves UTC',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'),
            (_) async => throw PlatformException(code: 'unavailable'),
          );
      var posts = 0;
      await http.runWithClient(
        () async {
          await pump(tester, kind: 'sleep');
          expect(
            find.textContaining('Could not detect your phone'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('Timezone'),
            150,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text('Timezone'), findsOneWidget);
          await tap(tester, 'Save session');
          expect(find.byType(CalendarHealthSheet), findsOneWidget);
        },
        () => MockClient((r) async {
          if (r.method == 'POST') posts++;
          return http.Response(jsonEncode(healthDay()), 200);
        }),
      );
      expect(posts, 0);
    },
  );

  testWidgets(
    'editing while travelling preserves the session timezone and instants',
    (tester) async {
      final session = {
        ...healthSession(kind: 'activity'),
        'timezone': 'Asia/Beirut',
      };
      Map? sent;
      await http.runWithClient(
        () async {
          await pump(tester, kind: 'activity', session: session);
          expect(find.text('Timezone'), findsNothing);
          expect(
            find.textContaining('saved with this session: Asia/Beirut'),
            findsOneWidget,
          );
          await tap(tester, 'Save session');
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(
              jsonEncode(healthDay(sessions: [session])),
              200,
            );
          }
          sent = jsonDecode(r.body) as Map;
          return healthCommitted(r);
        }),
      );
      expect(sent!['session']['timezone'], 'Asia/Beirut');
      expect(
        DateTime.parse(sent!['session']['started_at']),
        DateTime.parse(session['started_at'] as String),
      );
      expect(
        DateTime.parse(sent!['session']['ended_at']),
        DateTime.parse(session['ended_at'] as String),
      );
    },
  );

  testWidgets(
    'recovery opens without source read and retries exact saved request',
    (tester) async {
      final body = {
        'operation_key': 'lost-session-test',
        'action': 'delete',
        'source': {'id': 9, 'revision': 2},
      };
      await (await SharedPreferences.getInstance()).setString(
        'calendar_pending_health_u42',
        jsonEncode(body),
      );
      var reads = 0;
      Map? sent;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            healthApp(
              Scaffold(body: CalendarHealthBanner(onSaved: () async {})),
            ),
          );
          await tester.pumpAndSettle();
          await tap(tester, 'Review and retry session request');
          await tap(tester, 'Review and retry session request');
          expect(await CalendarHealthApi.pending(42), isNull);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') reads++;
          sent = jsonDecode(r.body) as Map;
          return healthCommitted(r);
        }),
      );
      expect(reads, 0);
      expect(sent, body);
    },
  );
  testWidgets('Arabic large text form on a small screen remains scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(
      () async {
        await pump(tester, kind: 'sleep', arabic: true);
        expect(tester.takeException(), isNull);
        await tap(tester, 'حفظ الجلسة');
        expect(find.byType(CalendarHealthSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (r) async => r.method == 'GET'
            ? http.Response(jsonEncode(healthDay()), 200)
            : healthCommitted(r),
      ),
    );
  });
  testWidgets(
    'a conflict requires reload and the next edit uses the fresh revision',
    (tester) async {
      var revision = 2;
      final writes = <Map>[];
      await http.runWithClient(
        () async {
          await pump(tester, kind: 'sleep', session: healthSession());
          await tap(tester, 'Save session');
          expect(find.textContaining('This session changed'), findsOneWidget);
          expect(await CalendarHealthApi.pending(42), isNull);
          revision = 3;
          await tap(tester, 'Reload session');
          await tap(tester, 'Save session');
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(
              jsonEncode(
                healthDay(
                  sessions: [
                    {
                      ...healthSession(),
                      'source': {'id': 9, 'revision': revision},
                    },
                  ],
                ),
              ),
              200,
            );
          }
          writes.add(jsonDecode(r.body) as Map);
          return writes.length == 1
              ? http.Response('{}', 409)
              : healthCommitted(r);
        }),
      );
      expect(writes.map((w) => w['source']['revision']), [2, 3]);
    },
  );
  testWidgets(
    'account switching hides a loaded form and keeps receipts scoped',
    (tester) async {
      var posts = 0;
      await http.runWithClient(
        () async {
          await pump(tester, kind: 'sleep');
          await (await SharedPreferences.getInstance()).setInt('user_id', 99);
          AccountStorage.accountChange.value++;
          await tester.pumpAndSettle();
          expect(
            find.textContaining('account', findRichText: false),
            findsWidgets,
          );
          expect(find.text('Save session'), findsNothing);
        },
        () => MockClient((r) async {
          if (r.method == 'POST') posts++;
          return http.Response(jsonEncode(healthDay()), 200);
        }),
      );
      expect(posts, 0);
    },
  );
  testWidgets('Arabic decimal distance is normalized before submission', (
    tester,
  ) async {
    Map? sent;
    await http.runWithClient(
      () async {
        await pump(tester, arabic: true);
        await tester.scrollUntilVisible(
          find.byType(TextField),
          150,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '٢٫١٢٥');
        await tap(tester, 'حفظ الجلسة');
      },
      () => MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(jsonEncode(healthDay()), 200);
        }
        sent = jsonDecode(r.body) as Map;
        return healthCommitted(r);
      }),
    );
    expect(sent!['session']['distance_km'], '2.125');
  });
  testWidgets(
    'daily summary opens above nutrition with every category and collapses',
    (tester) async {
      var reads = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            healthApp(
              DayTimelinePage(date: DateTime(2026, 1, 5), program: const {}),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Logged meals'), findsNothing);
          expect(
            tester.getTopLeft(find.text('Daily summary')).dy,
            lessThan(
              tester
                  .getTopLeft(find.byKey(const ValueKey('timeline-nutrition')))
                  .dy,
            ),
          );
          final before = reads;
          await tester.tap(find.text('Daily summary'));
          await tester.pumpAndSettle();
          TaqaTimelineSummaryCard card(String title) => tester.widget(
            find.byWidgetPredicate(
              (w) => w is TaqaTimelineSummaryCard && w.title == title,
            ),
          );
          expect(card('Logged meals').value, '2');
          expect(card('Logged meals').detail, contains('Breakfast'));
          expect(card('Logged meals').detail, contains('Untimed lunch'));
          expect(card('Planned meals').value, '1');
          expect(card('Planned meals').detail, 'Dinner plan');
          expect(card('Completed workouts').value, '2');
          expect(
            card('Completed workouts').detail,
            contains('Strength session'),
          );
          expect(card('Completed workouts').detail, contains('Cardio session'));
          expect(card('Planned').value, 'Evening workout');
          expect(card('Logged activities').value, startsWith('1'));
          expect(card('Logged activities').detail, contains('Walking'));
          expect(card('Sleep').detail, 'WHOOP sleep');
          expect(card('Daily activity').value, contains('9,000'));
          expect(find.textContaining('wearable data first'), findsNothing);
          expect(
            find.textContaining('These totals are never added'),
            findsNothing,
          );
          await tester.tap(find.text('Daily summary'));
          await tester.pumpAndSettle();
          expect(find.text('Logged meals'), findsNothing);
          expect(find.text('Completed workouts'), findsNothing);
          expect(reads, before);
          await tester.tap(find.byTooltip('Next day'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Daily summary'));
          await tester.pumpAndSettle();
          expect(card('Logged meals').value, '0');
          expect(card('Completed workouts').value, '0');
          expect(card('Logged activities').value, '0');
          expect(card('Sleep').value, 'Nothing logged yet');
        },
        () => MockClient((r) async {
          if (r.url.path.endsWith('/day') || r.url.path.endsWith('/sessions')) {
            reads++;
          }
          final date = r.url.queryParameters['entry_date'];
          final selected = date == '2026-01-05';
          if (r.url.path.endsWith('/sessions')) {
            return http.Response(
              jsonEncode({
                ...healthDay(),
                'entry_date': date,
                'sessions': selected ? [healthSession(kind: 'activity')] : [],
                'sleep_summary': {
                  'origin': selected ? 'whoop' : 'none',
                  'minutes': selected ? 480 : 0,
                },
              }),
              200,
            );
          }
          if (r.url.path.endsWith('/day')) {
            return http.Response(
              jsonEncode({
                'entry_date': date,
                'daily_summary': selected ? {'steps': 9000} : null,
                'planned_activity': selected
                    ? {
                        'schedule_type': 'training',
                        'training_day_label': 'Evening workout',
                        'scheduled_at': '2026-01-05T18:00:00Z',
                      }
                    : null,
                'events': selected
                    ? [
                        for (final row in [
                          ['meal', 'Breakfast', '2026-01-05T08:00:00Z'],
                          ['meal', 'Untimed lunch', null],
                          [
                            'planned_meal',
                            'Dinner plan',
                            '2026-01-05T19:00:00Z',
                          ],
                          [
                            'strength',
                            'Strength session',
                            '2026-01-05T10:00:00Z',
                          ],
                          ['cardio', 'Cardio session', null],
                        ])
                          {
                            'id': row[1],
                            'type': row[0],
                            'title': row[1],
                            'occurred_at': row[2],
                            'details': {},
                          },
                      ]
                    : [],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
    },
  );

  testWidgets(
    'expanded daily summary fits a small Arabic screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            healthApp(
              DayTimelinePage(date: DateTime(2026, 1, 5), program: const {}),
              arabic: true,
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('ملخص اليوم'));
          await tester.tap(find.text('ملخص اليوم'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('الأنشطة المسجلة'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('الأنشطة المسجلة'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((r) async {
          if (r.url.path.endsWith('/sessions')) {
            return http.Response(
              jsonEncode(
                healthDay(sessions: [healthSession(kind: 'activity')]),
              ),
              200,
            );
          }
          if (r.url.path.endsWith('/day')) {
            return http.Response(
              '{"entry_date":"2026-01-05","events":[]}',
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
    },
  );

  for (final hasTimedSleep in [false, true]) {
    testWidgets(
      'timed sleep is the only manual sleep writer, existing session: $hasTimedSleep',
      (tester) async {
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              healthApp(
                DayTimelinePage(date: DateTime(2026, 1, 5), program: const {}),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Log timed sleep'), findsOneWidget);
            await tester.tap(find.text('Daily summary'));
            await tester.pumpAndSettle();
            final sleepCard = find.byWidgetPredicate(
              (w) => w is TaqaTimelineSummaryCard && w.title == 'Sleep',
            );
            await tester.scrollUntilVisible(
              sleepCard,
              150,
              scrollable: find.byType(Scrollable).first,
            );
            final summary = tester.widget<TaqaTimelineSummaryCard>(sleepCard);
            expect(summary.onEdit, isNull);
            expect(
              summary.detail,
              contains(hasTimedSleep ? 'Logged sleep' : 'Saved sleep duration'),
            );
            await tester.scrollUntilVisible(
              find.text('LOG FOOD'),
              100,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text('EDIT DAILY SLEEP DURATION'), findsNothing);
            expect(find.text('EDIT SLEEP'), findsNothing);
            expect(find.text('LOG SLEEP'), findsNothing);
            await tester.scrollUntilVisible(
              find.text('Log timed sleep'),
              -150,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(find.text('Log timed sleep'));
            await tester.pumpAndSettle();
            expect(find.byType(CalendarHealthSheet), findsOneWidget);
          },
          () => MockClient((r) async {
            if (r.url.path.endsWith('/sessions')) {
              return http.Response(
                jsonEncode({
                  ...healthDay(
                    sessions: hasTimedSleep ? [healthSession()] : [],
                  ),
                  'sleep_summary': {
                    'origin': hasTimedSleep
                        ? 'manual_sessions'
                        : 'daily_metrics',
                    'minutes': hasTimedSleep ? 480 : 420,
                  },
                }),
                200,
              );
            }
            if (r.url.path.endsWith('/day')) {
              return http.Response(
                jsonEncode({
                  'entry_date': '2026-01-05',
                  'daily_summary': {'sleep_minutes_asleep': 420},
                  'events': [],
                }),
                200,
              );
            }
            return http.Response('{}', 404);
          }),
        );
      },
    );
  }

  testWidgets(
    'manual sleep renders at wake hour and hourly add offers all three types',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            healthApp(
              DayTimelinePage(date: DateTime(2026, 1, 5), program: const {}),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(TaqaHourlyTimeline),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          final rail = tester.widget<TaqaHourlyTimeline>(
            find.byType(TaqaHourlyTimeline),
          );
          expect(rail.eventsByHour[7], hasLength(1));
          expect(rail.eventsByHour[23], isNull);
          rail.onEmptyHourTap!(8);
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ListTile, 'Log food'), findsOneWidget);
          expect(find.widgetWithText(ListTile, 'Log activity'), findsOneWidget);
          expect(
            find.widgetWithText(ListTile, 'Log timed sleep'),
            findsOneWidget,
          );
          await tester.tap(find.widgetWithText(ListTile, 'Log activity'));
          await tester.pumpAndSettle();
          expect(find.byType(CalendarHealthSheet), findsOneWidget);
        },
        () => MockClient((r) async {
          if (r.url.path.endsWith('/sessions')) {
            return http.Response(
              jsonEncode(healthDay(sessions: [healthSession()])),
              200,
            );
          }
          if (r.url.path.endsWith('/day')) {
            return http.Response(
              jsonEncode({'entry_date': '2026-01-05', 'events': []}),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
    },
  );
  testWidgets(
    'month marks manual sessions and stays usable with Arabic large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = calendarDate(DateTime.now());
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            healthApp(const CalendarPage(program: {}), arabic: true),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('الجلسات اليدوية'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('الجلسات اليدوية'), findsOneWidget);
          expect(find.text('2'), findsWidgets);
          await tester.scrollUntilVisible(
            find.textContaining('نوم WHOOP'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining('نوم WHOOP'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((r) async {
          if (r.url.path.endsWith('/session-days')) {
            return http.Response(
              jsonEncode({
                'days': [
                  {'entry_date': date, 'sleep_count': 1, 'activity_count': 1},
                ],
              }),
              200,
            );
          }
          if (r.url.path.endsWith('/sessions')) {
            return http.Response(
              jsonEncode({
                ...healthDay(),
                'entry_date': date,
                'sleep_summary': {
                  'origin': 'whoop',
                  'minutes': 480,
                  'manual_duration_seconds': 0,
                  'manual_sessions_used': false,
                },
              }),
              200,
            );
          }
          return http.Response(
            r.url.path.endsWith('/range-summary') ? '{"days":[]}' : '[]',
            200,
          );
        }),
      );
    },
  );
  testWidgets(
    'day navigation refetches the selected day and optional health failure keeps food available',
    (tester) async {
      final dates = <String>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            healthApp(
              DayTimelinePage(date: DateTime(2026, 1, 31), program: const {}),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Choose date'), findsNothing);
          expect(find.byTooltip('Previous day'), findsOneWidget);
          await tester.tap(find.byTooltip('Next day'));
          await tester.pumpAndSettle();
          expect(dates, ['2026-01-31', '2026-02-01']);
          expect(
            find.text('Could not load activity and sleep logs. Tap to retry.'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('LOG FOOD'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('LOG FOOD'), findsOneWidget);
          expect(find.text('LOG SLEEP'), findsNothing);
          expect(find.text('EDIT SLEEP'), findsNothing);
          await tester.scrollUntilVisible(
            find.byTooltip('Previous day'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.byTooltip('Previous day'));
          await tester.pumpAndSettle();
          expect(dates, ['2026-01-31', '2026-02-01', '2026-01-31']);
        },
        () => MockClient((r) async {
          if (r.url.path.endsWith('/day')) {
            final d = r.url.queryParameters['entry_date']!;
            dates.add(d);
            return http.Response(
              jsonEncode({
                'entry_date': d,
                'events': [],
                'daily_summary': null,
                'planned_activity': null,
              }),
              200,
            );
          }
          return http.Response(
            '{}',
            r.url.path.endsWith('/sessions') ? 500 : 404,
          );
        }),
      );
    },
  );
}
