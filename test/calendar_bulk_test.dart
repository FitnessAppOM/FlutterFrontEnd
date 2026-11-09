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
import 'package:taqaproject/screens/calendar/calendar_bulk_sheet.dart';
import 'package:taqaproject/screens/calendar/calendar_pending_move_banner.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'services/calendar/calendar_bulk_commands_test.dart' show bulkFoodJson;
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

  Future<void> pump(WidgetTester tester, {bool arabic = false}) async {
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
                    onPressed: () => showCalendarBulkEditor(
                      context,
                      userId: 42,
                      date: DateTime(2026, 1, 5),
                      references: [
                        {'kind': 'meal', 'id': 12},
                        {'kind': 'meal', 'id': 13},
                      ],
                    ),
                    child: const Text('Open selection'),
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  http.Response state(
    http.Request r, {
    bool available = true,
    String revision = 'a',
  }) {
    final id = int.parse(r.url.pathSegments.last);
    final json = bulkFoodJson(
      id: id,
      at: '2026-01-05T${id == 12 ? '10' : '14'}:00:00Z',
    );
    json['source']['revision'] = revision * 64;
    if (!available) json['capabilities'] = ['edit_time'];
    return http.Response(jsonEncode(json), 200);
  }

  testWidgets(
    'select all copies both meals with separate times in one request',
    (tester) async {
      Map? sent;
      await http.runWithClient(
        () async {
          await pump(tester);
          await tap(tester, find.text('Open selection'));
          expect(find.text('Manage meals'), findsOneWidget);
          expect(find.textContaining('copy to another date'), findsOneWidget);
          expect(find.text('0 selected'), findsOneWidget);
          await tap(tester, find.text('Select all meals'));
          expect(find.text('2 selected'), findsOneWidget);
          await tap(tester, find.text('Copy selected'));
          expect(find.byType(CalendarBulkSheet), findsNothing);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') return state(r);
          sent = jsonDecode(r.body) as Map;
          expect(r.url.path, endsWith('/food/bulk'));
          return committed(r);
        }),
      );
      expect(sent!['action'], 'copy');
      final entries = sent!['entries'] as List;
      expect(entries.length, 2);
      expect(entries[0].containsKey('item_ids'), false);
      final first = DateTime.parse(
        entries[0]['destinations'][0]['scheduled_at'],
      );
      final second = DateTime.parse(
        entries[1]['destinations'][0]['scheduled_at'],
      );
      expect(second.difference(first), const Duration(hours: 4));
    },
  );
  testWidgets('delete requires confirmation and cancel sends no request', (
    tester,
  ) async {
    var posts = 0;
    await http.runWithClient(
      () async {
        await pump(tester);
        await tap(tester, find.text('Open selection'));
        await tap(tester, find.byKey(const ValueKey('bulk-parent-meal-12')));
        await tap(tester, find.widgetWithText(ChoiceChip, 'Delete'));
        await tap(tester, find.text('Delete selected'));
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pumpAndSettle();
        expect(posts, 0);
        await tap(tester, find.text('Delete selected'));
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Delete'),
          ),
        );
        await tester.pumpAndSettle();
        expect(posts, 1);
      },
      () => MockClient((r) async {
        if (r.method == 'GET') return state(r);
        posts++;
        expect(jsonDecode(r.body)['action'], 'delete');
        return committed(r);
      }),
    );
  });
  testWidgets(
    'response loss recovers a bulk request from banner without source reads',
    (tester) async {
      final bodies = <String>[];
      var reads = 0;
      await http.runWithClient(
        () async {
          await pump(tester);
          await tap(tester, find.text('Open selection'));
          await tap(tester, find.text('Select all meals'));
          await tap(tester, find.text('Copy selected'));
          expect(await CalendarFoodCommands.pending(42), isNotNull);
          await tap(tester, find.text('Cancel').last);
          final initialReads = reads;
          await tap(tester, find.text('Review and retry food changes'));
          await tap(
            tester,
            find.widgetWithText(FilledButton, 'Review and retry food changes'),
          );
          expect(reads, initialReads);
          expect(await CalendarFoodCommands.pending(42), isNull);
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            reads++;
            return state(r);
          }
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('lost response');
          return committed(r);
        }),
      );
      expect(bodies.length, 2);
      expect(bodies[0], bodies[1]);
    },
  );
  testWidgets(
    'stale selection reload retains choice but sends new revision and key',
    (tester) async {
      final bodies = <Map>[];
      await http.runWithClient(
        () async {
          await pump(tester);
          await tap(tester, find.text('Open selection'));
          await tap(tester, find.byKey(const ValueKey('bulk-parent-meal-12')));
          await tap(tester, find.text('Copy selected'));
          expect(await CalendarFoodCommands.pending(42), isNull);
          // Use the localized key so copy/time recovery wording can evolve together.
          final context = tester.element(find.byType(CalendarBulkSheet));
          final label = AppLocalizations.of(
            context,
          ).translate('calendar_time_reload');
          await tap(tester, find.widgetWithText(TextButton, label));
          await tap(tester, find.text('Copy selected'));
        },
        () => MockClient((r) async {
          if (r.method == 'GET') {
            return state(r, revision: bodies.isEmpty ? 'a' : 'b');
          }
          bodies.add(jsonDecode(r.body) as Map);
          return bodies.length == 1 ? http.Response('{}', 409) : committed(r);
        }),
      );
      expect(bodies.last['entries'][0]['source']['revision'], 'b' * 64);
      expect(
        bodies.first['operation_key'],
        isNot(bodies.last['operation_key']),
      );
      expect((bodies.last['entries'] as List).length, 1);
    },
  );
  testWidgets(
    'Arabic large text is scrollable and unavailable capability disables selection',
    (tester) async {
      await http.runWithClient(() async {
        await pump(tester, arabic: true);
        await tap(tester, find.text('Open selection'));
        final context = tester.element(find.byType(CalendarBulkSheet));
        await tap(
          tester,
          find.text(
            AppLocalizations.of(context).translate('calendar_bulk_all'),
          ),
        );
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, () => MockClient((r) async => state(r)));
      await tester.pumpWidget(const SizedBox());
      await http.runWithClient(() async {
        await pump(tester);
        await tap(tester, find.text('Open selection'));
        expect(find.text('Select all meals'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
      }, () => MockClient((r) async => state(r, available: false)));
    },
  );
}
