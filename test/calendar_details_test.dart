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
import 'package:taqaproject/screens/calendar/calendar_details_sheet.dart';
import 'package:taqaproject/screens/calendar/calendar_pending_move_banner.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'services/calendar/calendar_details_commands_test.dart'
    show detailsFoodJson, recipeJson;
import 'services/calendar/calendar_food_commands_test.dart' show committed;

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
    WidgetTester tester,
    String action, {
    bool arabic = false,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
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
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showCalendarDetails(
                      context,
                      userId: 42,
                      action: action,
                      date: DateTime(2026, 1, 5),
                      kind: 'meal',
                      foodId: 12,
                      itemId: 1,
                      entries: [
                        {
                          'source': detailsFoodJson()['source'],
                          'destinations': <Map<String, dynamic>>[],
                        },
                      ],
                    ),
                    child: const Text('Open details'),
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
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), value);
    await tester.pumpAndSettle();
  }

  http.Response read(http.Request r, {String revision = 'a'}) {
    if (r.url.path.endsWith('/recipes')) {
      return http.Response(
        jsonEncode({
          'recipes': [
            {'id': 5, 'name': 'Rice recipe', 'servings': 4},
          ],
        }),
        200,
      );
    }
    if (r.url.path.endsWith('/recipes/5')) {
      return http.Response(jsonEncode(recipeJson()), 200);
    }
    final state = detailsFoodJson();
    state['source']['revision'] = revision * 64;
    return http.Response(jsonEncode(state), 200);
  }

  testWidgets(
    'recipe creation requires explicit item-total policy and carries serving metadata',
    (tester) async {
      Map? sent;
      await http.runWithClient(
        () async {
          await pump(tester, 'recipe');
          await enter(tester, 'Recipe name', 'Breakfast bowl');
          await enter(tester, 'Servings in the full recipe', '4');
          await enter(tester, 'Total prepared weight (g, optional)', '800');
          await tap(tester, find.widgetWithText(FilledButton, 'Save'));
          expect(sent, isNull);
          expect(
            find.textContaining('custom totals shown below'),
            findsOneWidget,
          );
          await tap(tester, find.byType(CheckboxListTile));
          await tap(tester, find.widgetWithText(FilledButton, 'Save'));
          expect(find.byType(CalendarDetailsSheet), findsNothing);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') return read(r);
          expect(r.url.path, endsWith('/food/recipe'));
          sent = jsonDecode(r.body) as Map;
          return committed(r);
        }),
      );
      expect(sent!['nutrition_policy'], 'item_totals');
      expect(sent!['servings'], '4');
      expect(sent!['prepared_weight_g'], 800);
      expect(sent!['entries'][0].containsKey('calories'), false);
    },
  );
  testWidgets(
    'fractional recipe logging previews and sends one serving request',
    (tester) async {
      Map? sent;
      await http.runWithClient(
        () async {
          await pump(tester, 'recipe-log');
          await enter(tester, 'Servings to log', '0.5');
          expect(find.textContaining('Calories (kcal): 35'), findsOneWidget);
          await tap(tester, find.widgetWithText(FilledButton, 'Save'));
        },
        () => MockClient((r) async {
          if (r.method == 'GET') return read(r);
          expect(r.url.path, endsWith('/food/recipe-log'));
          sent = jsonDecode(r.body) as Map;
          return committed(r);
        }),
      );
      expect(sent!['servings'], '0.5');
      expect(sent!['recipe']['revision'], 'b' * 64);
      expect(sent!['destination']['expected_status'], 'logged');
    },
  );
  testWidgets('portion editing keeps overrides unless explicitly cleared', (
    tester,
  ) async {
    Map? sent;
    await http.runWithClient(
      () async {
        await pump(tester, 'edit-item');
        await enter(tester, 'Portion multiplier', '0.5');
        expect(find.textContaining('Calories (kcal): 100'), findsOneWidget);
        await tap(tester, find.widgetWithText(FilledButton, 'Save'));
      },
      () => MockClient((r) async {
        if (r.method == 'GET') return read(r);
        sent = jsonDecode(r.body) as Map;
        return committed(r);
      }),
    );
    expect(sent!['quantity_multiplier'], '0.5');
    expect(sent!['override_policy'], 'preserve');
    expect(sent!.containsKey('nutrition'), false);
  });
  testWidgets(
    'manual macros and clearing overrides are explicit and survive stale reload',
    (tester) async {
      final bodies = <Map>[];
      await http.runWithClient(
        () async {
          await pump(tester, 'edit-item');
          await tap(
            tester,
            find.widgetWithText(
              SwitchListTile,
              'Enter final calories and macros manually',
            ),
          );
          await enter(tester, 'Calories (kcal)', '321');
          await tap(
            tester,
            find.widgetWithText(SwitchListTile, 'Remove meal custom totals'),
          );
          await tap(tester, find.widgetWithText(FilledButton, 'Save'));
          final context = tester.element(find.byType(CalendarDetailsSheet));
          await tap(
            tester,
            find.widgetWithText(
              TextButton,
              AppLocalizations.of(context).translate('calendar_time_reload'),
            ),
          );
          await tap(tester, find.widgetWithText(FilledButton, 'Save'));
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            return read(r, revision: bodies.isEmpty ? 'a' : 'b');
          }
          bodies.add(jsonDecode(r.body) as Map);
          return bodies.length == 1 ? http.Response('{}', 409) : committed(r);
        }),
      );
      expect(bodies.last['override_policy'], 'clear');
      expect(bodies.last['nutrition']['calories'], 321);
      expect(bodies.last['source']['revision'], 'b' * 64);
      expect(
        bodies.last['operation_key'],
        isNot(bodies.first['operation_key']),
      );
    },
  );
  testWidgets(
    'lost recipe-log response recovers from banner without template reads',
    (tester) async {
      final bodies = <String>[];
      var gets = 0;
      await http.runWithClient(
        () async {
          await pump(tester, 'recipe-log');
          await enter(tester, 'Servings to log', '0.5');
          await tap(tester, find.widgetWithText(FilledButton, 'Save'));
          expect((await CalendarFoodCommands.pending(42))!.kind, 'recipe');
          await tap(tester, find.text('Cancel').last);
          final before = gets;
          await tap(tester, find.text('Review and retry saved food request'));
          await tap(
            tester,
            find.widgetWithText(
              FilledButton,
              'Review and retry saved food request',
            ),
          );
          expect(gets, before);
          expect(await CalendarFoodCommands.pending(42), isNull);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            gets++;
            return read(r);
          }
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('lost');
          return committed(r);
        }),
      );
      expect(bodies.first, bodies.last);
    },
  );
  testWidgets('Arabic recipe form supports large text and scrolling', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pump(tester, 'recipe', arabic: true);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => MockClient((r) async => read(r)));
  });
}
