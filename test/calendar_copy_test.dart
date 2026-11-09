import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/calendar/calendar_copy_sheet.dart';
import 'package:taqaproject/screens/calendar/calendar_meal_editor_sheet.dart';
import 'package:taqaproject/screens/calendar/calendar_pending_move_banner.dart';
import 'package:taqaproject/screens/calendar/calendar_time_editor_sheet.dart';
import 'package:taqaproject/services/calendar/day_timeline_service.dart';
import 'services/calendar/calendar_copy_commands_test.dart' show copyFoodJson;
import 'services/calendar/calendar_food_commands_test.dart' show committed;

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
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        ),
  );

  Future<void> pump(
    WidgetTester tester, {
    String kind = 'meal',
    Locale locale = const Locale('en'),
    double scale = 1,
    Widget? child,
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
            ).copyWith(textScaler: TextScaler.linear(scale)),
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
                          kind: kind,
                          foodId: 12,
                          copy: true,
                        ),
                        child: const Text('Open copy'),
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
    await tester.tap(find.text('Open copy'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> finishToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selected food and multiple dates are submitted under one command',
    (tester) async {
      Map<String, dynamic>? sent;
      await http.runWithClient(
        () async {
          await pump(tester);
          await open(tester);
          await tester.tap(find.byType(SwitchListTile));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Whole-meal overrides are not included'),
            findsOneWidget,
          );
          await tester.tap(find.widgetWithText(CheckboxListTile, 'Rice'));
          await tester.pumpAndSettle();
          await tapVisible(tester, find.text('Add another date'));
          await tester.tap(find.byIcon(Icons.edit_outlined).last);
          await tester.pumpAndSettle();
          final tomorrow = DateTime.now().add(const Duration(days: 2));
          await tester.enterText(
            find.byType(TextField).last,
            DateFormat.yMd('en').format(tomorrow),
          );
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Save as planned'), findsWidgets);
          await tapVisible(tester, find.text('Confirm copy'));
          await finishToast(tester);
          expect(find.byType(CalendarCopySheet), findsNothing);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(jsonEncode(copyFoodJson()), 200);
          }
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return committed(r);
        }),
      );
      expect(sent!['item_ids'], [2]);
      expect(sent!['destinations'], hasLength(2));
      expect(
        (sent!['destinations'] as List).last['expected_status'],
        'planned',
      );
      expect(sent!.containsKey('overrides'), isFalse);
    },
  );

  testWidgets(
    'planned item selection sends stable keys rather than display IDs',
    (tester) async {
      Map<String, dynamic>? sent;
      await http.runWithClient(
        () async {
          await pump(tester, kind: 'meal_plan');
          await open(tester);
          await tester.tap(find.byType(SwitchListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(CheckboxListTile, 'Rice'));
          await tester.pumpAndSettle();
          await tapVisible(tester, find.text('Confirm copy'));
          await finishToast(tester);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(
              jsonEncode(copyFoodJson(kind: 'meal_plan')),
              200,
            );
          }
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return committed(r);
        }),
      );
      expect(sent!['item_keys'], ['00000000-0000-4000-8000-000000000002']);
      expect(sent!.containsKey('item_ids'), isFalse);
    },
  );

  testWidgets(
    'copy recovery reopens the correct sheet and replays identical payload',
    (tester) async {
      final bodies = <String>[];
      var gets = 0;
      await http.runWithClient(
        () async {
          await pump(tester);
          await open(tester);
          await tapVisible(tester, find.text('Confirm copy'));
          await tapVisible(tester, find.text('Cancel'));
          await tapVisible(tester, find.text('Check copy / retry'));
          expect(find.byType(CalendarCopySheet), findsOneWidget);
          expect(find.byType(SwitchListTile), findsNothing);
          await tapVisible(
            tester,
            find.widgetWithText(FilledButton, 'Check copy / retry'),
          );
          await finishToast(tester);
          expect(find.byType(CalendarCopySheet), findsNothing);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            gets++;
            return http.Response(jsonEncode(copyFoodJson()), 200);
          }
          expect(r.url.path, endsWith('/food/copy'));
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('lost');
          return committed(r);
        }),
      );
      expect(gets, 1);
      expect(bodies, hasLength(2));
      expect(bodies.first, bodies.last);
      expect(
        (jsonDecode(bodies.first) as Map).containsKey('item_ids'),
        isFalse,
      );
    },
  );

  testWidgets('copy sheet supports Arabic large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(
      () async {
        await pump(tester, locale: const Locale('ar'), scale: 1.6);
        await open(tester);
        expect(find.text('نسخ الطعام'), findsOneWidget);
        await tester.ensureVisible(find.text('تأكيد النسخ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (_) async => http.Response(jsonEncode(copyFoodJson()), 200),
      ),
    );
  });

  testWidgets(
    'copy capability appears in existing editor and overridden plans explain content restrictions',
    (tester) async {
      await http.runWithClient(
        () async {
          await pump(
            tester,
            child: CalendarMealEditorSheet(
              event: const DayTimelineEvent(
                id: 'planned-meal-12',
                type: 'planned_meal',
                title: 'Lunch',
                occurredAt: null,
                details: {'plan_id': 12, 'items': []},
              ),
              mealDate: DateTime(2026, 1, 5),
              onChanged: () async {},
            ),
          );
          expect(find.text('COPY FOOD'), findsOneWidget);
          expect(find.textContaining('adjusted totals'), findsOneWidget);
          await tapVisible(tester, find.text('COPY FOOD'));
          expect(find.byType(CalendarCopySheet), findsOneWidget);
        },
        () => MockClient(
          (_) async =>
              http.Response(jsonEncode(copyFoodJson(kind: 'meal_plan')), 200),
        ),
      );
    },
  );
}
