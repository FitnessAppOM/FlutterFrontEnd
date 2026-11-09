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
import 'package:taqaproject/screens/calendar/calendar_meal_editor_sheet.dart';
import 'package:taqaproject/screens/calendar/calendar_pending_move_banner.dart';
import 'package:taqaproject/screens/calendar/calendar_time_editor_sheet.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'package:taqaproject/services/calendar/day_timeline_service.dart';

import 'services/calendar/calendar_food_commands_test.dart'
    show foodJson, committed;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 42});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => 'Asia/Beirut',
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        );
  });

  Future<void> pump(
    WidgetTester tester, {
    Widget? child,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          locale: locale,
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
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body:
                child ??
                Builder(
                  builder: (context) => Column(
                    children: [
                      TextButton(
                        onPressed: () => showCalendarTimeEditor(
                          context,
                          userId: 42,
                          kind: 'meal',
                          foodId: 12,
                        ),
                        child: const Text('Open'),
                      ),
                      CalendarPendingMoveBanner(onSaved: () async {}),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('date selection previews and submits an offset-bearing move', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    await http.runWithClient(
      () async {
        await pump(tester);
        await open(tester);
        expect(find.text('Current logged date: 2026-01-05'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await tester.tap(find.byIcon(Icons.calendar_month));
        await tester.pumpAndSettle();
        await tester.tap(find.text('6').last);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Jan 6, 2026 12:00'), findsOneWidget);
        await save(tester);
        expect(find.byType(CalendarTimeEditorSheet), findsNothing);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(foodJson()), 200);
        }
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return committed(request);
      }),
    );
    expect(submitted!['scheduled_date'], '2026-01-06');
    expect(submitted!['timezone'], 'Asia/Beirut');
    expect(submitted!['scheduled_at'], '2026-01-06T12:00:00+02:00');
  });

  testWidgets('timezone choice appears only when phone detection fails', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    Map<String, dynamic>? submitted;
    await http.runWithClient(
      () async {
        await pump(tester);
        await open(tester);
        final picker = find.byType(DropdownButtonFormField<String>);
        expect(picker, findsOneWidget);
        await save(tester);
        expect(submitted, isNull);
        await tester.ensureVisible(picker);
        await tester.pumpAndSettle();
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Africa/Abidjan').last);
        await tester.pumpAndSettle();
        await save(tester);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(foodJson()), 200);
        }
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return committed(request);
      }),
    );
    expect(submitted!['timezone'], 'Africa/Abidjan');
    expect(submitted!['scheduled_at'], endsWith('+00:00'));
  });

  testWidgets(
    'lost response can be recovered from banner after closing editor without refetching deleted food',
    (tester) async {
      final bodies = <String>[];
      var gets = 0;
      await http.runWithClient(
        () async {
          await pump(tester);
          await open(tester);
          await save(tester);
          expect(
            find.textContaining("We couldn't confirm the save."),
            findsWidgets,
          );
          await tester.ensureVisible(find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(CalendarTimeEditorSheet), findsNothing);
          await tester.tap(find.text('Check saved time / retry'));
          await tester.pumpAndSettle();
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
          final retry = find.widgetWithText(
            FilledButton,
            'Check saved time / retry',
          );
          await tester.ensureVisible(retry);
          await tester.tap(retry);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(find.byType(CalendarTimeEditorSheet), findsNothing);
          expect(await CalendarFoodCommands.pending(42), isNull);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') {
            gets++;
            return gets == 1
                ? http.Response(jsonEncode(foodJson()), 200)
                : http.Response('{}', 404);
          }
          bodies.add(request.body);
          if (bodies.length == 1) throw http.ClientException('Lost');
          return committed(request);
        }),
      );
      expect(gets, 1);
      expect(bodies, hasLength(2));
      expect(bodies[0], bodies[1]);
    },
  );

  testWidgets('stale revision requires reload then uses new revision and key', (
    tester,
  ) async {
    var gets = 0;
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(
      () async {
        await pump(tester);
        await open(tester);
        await save(tester);
        expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
        await tester.tap(find.text('Reload meal'));
        await tester.pumpAndSettle();
        await save(tester);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          final state = foodJson();
          state['source']['revision'] = (++gets == 1 ? 'a' : 'b') * 64;
          return http.Response(jsonEncode(state), 200);
        }
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return requests.length == 1
            ? http.Response('{}', 409)
            : committed(request);
      }),
    );
    expect(requests, hasLength(2));
    expect(requests[0]['operation_key'], isNot(requests[1]['operation_key']));
    expect(requests[1]['source']['revision'], 'b' * 64);
  });

  testWidgets(
    'disabled backend hides time action while keeping meal builder actions',
    (tester) async {
      await http.runWithClient(() async {
        await pump(
          tester,
          child: SingleChildScrollView(
            child: CalendarMealEditorSheet(
              event: const DayTimelineEvent(
                id: 'meal-12',
                type: 'meal',
                title: 'Lunch',
                occurredAt: null,
                details: {'items': []},
              ),
              mealDate: DateTime(2026, 1, 5),
              onChanged: () async {},
            ),
          ),
        );
        expect(find.text('EDIT DATE & TIME'), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.edit_outlined),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      }, () => MockClient((_) async => http.Response('{}', 503)));
    },
  );

  testWidgets(
    'Arabic large text time editor is scrollable without layout errors',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await http.runWithClient(
        () async {
          await pump(tester, locale: const Locale('ar'), textScale: 1.6);
          await open(tester);
          expect(find.text('تعديل التاريخ والوقت'), findsOneWidget);
          await tester.ensureVisible(find.widgetWithText(FilledButton, 'حفظ'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        () =>
            MockClient((_) async => http.Response(jsonEncode(foodJson()), 200)),
      );
    },
  );

  testWidgets(
    'existing meal editor opens time action and refreshes once after save',
    (tester) async {
      var changed = 0;
      await http.runWithClient(
        () async {
          await pump(
            tester,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CalendarMealEditorSheet(
                    event: const DayTimelineEvent(
                      id: 'meal-12',
                      type: 'meal',
                      title: 'Lunch',
                      occurredAt: null,
                      details: {'items': []},
                    ),
                    mealDate: DateTime(2026, 1, 5),
                    onChanged: () async {
                      changed++;
                    },
                  ),
                ),
                child: const Text('Meal'),
              ),
            ),
          );
          await tester.tap(find.text('Meal'));
          await tester.pumpAndSettle();
          expect(find.byType(CalendarMealEditorSheet), findsOneWidget);
          await tester.tap(find.text('EDIT DATE & TIME'));
          await tester.pumpAndSettle();
          expect(find.byType(CalendarTimeEditorSheet), findsOneWidget);
          await save(tester);
          expect(changed, 1);
          expect(find.byType(CalendarMealEditorSheet), findsNothing);
        },
        () => MockClient(
          (r) async => r.method == 'GET'
              ? http.Response(jsonEncode(foodJson()), 200)
              : committed(r),
        ),
      );
    },
  );
}
