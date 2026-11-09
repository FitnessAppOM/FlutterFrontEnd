import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/components/taqa_timeline.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/calendar/calendar_bulk_sheet.dart';
import 'package:taqaproject/screens/calendar/calendar_details_sheet.dart';
import 'package:taqaproject/screens/calendar/day_timeline_page.dart';
import 'package:taqaproject/widgets/diet_manual_entry_sheet.dart';
import 'package:taqaproject/widgets/diet_item_search_sheet.dart';
import 'package:taqaproject/widgets/diet_photo_entry_sheet.dart';

import 'calendar_health_test.dart' show healthApp;
import 'services/calendar/calendar_bulk_commands_test.dart' show bulkFoodJson;
import 'services/calendar/calendar_details_commands_test.dart' show recipeJson;

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

  http.Response read(http.Request r, {bool extras = true}) {
    if (r.url.path.endsWith('/day')) {
      return http.Response(
        jsonEncode({
          'entry_date': '2026-01-05',
          'events': [
            {
              'id': 'meal-12',
              'type': 'meal',
              'title': 'Lunch',
              'occurred_at': '2026-01-05T12:00:00Z',
              'details': {},
            },
          ],
        }),
        200,
      );
    }
    if (extras && r.url.path.endsWith('/food/meal/12')) {
      return http.Response(jsonEncode(bulkFoodJson()), 200);
    }
    if (extras && r.url.path.endsWith('/recipes')) {
      return http.Response(
        jsonEncode({
          'recipes': [recipeJson()],
        }),
        200,
      );
    }
    if (extras && r.url.path.endsWith('/recipes/5')) {
      return http.Response(jsonEncode(recipeJson()), 200);
    }
    return http.Response('{}', 404);
  }

  Future<void> pumpDay(WidgetTester tester, {bool arabic = false}) async {
    await tester.pumpWidget(
      healthApp(
        DayTimelinePage(date: DateTime(2026, 1, 5), program: const {}),
        arabic: arabic,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('one Log food button above nutrition opens all food options', (
    tester,
  ) async {
    var posts = 0;
    await http.runWithClient(
      () async {
        await pumpDay(tester);
        expect(find.text('LOG FOOD'), findsOneWidget);
        expect(find.text('Manage meals'), findsNothing);
        expect(find.text('Log recipe or favorite'), findsNothing);
        expect(
          tester.getTopLeft(find.text('LOG FOOD')).dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('timeline-nutrition')))
                .dy,
          ),
        );
        await tap(tester, find.text('LOG FOOD'));
        for (final label in [
          'Search',
          'Manual Entry',
          'Photo (AI estimate)',
          'Log recipe or favorite',
          'Manage meals',
        ]) {
          expect(find.widgetWithText(ListTile, label), findsOneWidget);
        }
        expect(find.text('Set meal time'), findsNothing);
        await tap(tester, find.text('Cancel'));
        expect(find.text('Manage meals'), findsNothing);
      },
      () => MockClient((r) async {
        if (r.method == 'POST') posts++;
        return read(r);
      }),
    );
    expect(posts, 0);
  });

  testWidgets('Manage meals opens existing selection without a time prompt', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpDay(tester);
      await tap(tester, find.text('LOG FOOD'));
      await tap(tester, find.widgetWithText(ListTile, 'Manage meals'));
      expect(find.byType(CalendarBulkSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('bulk-parent-meal-12')), findsOneWidget);
      expect(find.text('Set meal time'), findsNothing);
    }, () => MockClient((r) async => read(r)));
  });

  testWidgets('hourly food menu opens recipe logging with the selected hour', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpDay(tester);
      await tester.scrollUntilVisible(
        find.byType(TaqaHourlyTimeline),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      tester
          .widget<TaqaHourlyTimeline>(find.byType(TaqaHourlyTimeline))
          .onEmptyHourTap!(17);
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.widgetWithText(ListTile, 'Log recipe or favorite'),
      );
      expect(find.byType(CalendarDetailsSheet), findsOneWidget);
      expect(find.text('Rice recipe'), findsWidgets);
      final context = tester.element(find.byType(CalendarDetailsSheet));
      expect(
        find.text(const TimeOfDay(hour: 17, minute: 0).format(context)),
        findsOneWidget,
      );
      expect(find.text('Set meal time'), findsNothing);
    }, () => MockClient((r) async => read(r)));
  });

  for (final option in ['Search', 'Manual Entry', 'Photo (AI estimate)']) {
    testWidgets('$option keeps its builder after selecting a meal time', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await pumpDay(tester);
        await tap(tester, find.text('LOG FOOD'));
        await tap(tester, find.widgetWithText(ListTile, option));
        expect(find.text('Set meal time'), findsOneWidget);
        await tap(tester, find.text('SAVE'));
        expect(
          find.byType(switch (option) {
            'Search' => DietItemSearchSheet,
            'Manual Entry' => DietManualEntrySheet,
            _ => DietPhotoEntrySheet,
          }),
          findsOneWidget,
        );
      }, () => MockClient((r) async => read(r)));
    });
  }

  testWidgets('old backend keeps the three original food entry methods', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpDay(tester);
      await tap(tester, find.text('LOG FOOD'));
      expect(find.widgetWithText(ListTile, 'Search'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Manual Entry'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Photo (AI estimate)'),
        findsOneWidget,
      );
      expect(find.text('Manage meals'), findsNothing);
      expect(find.text('Log recipe or favorite'), findsNothing);
    }, () => MockClient((r) async => read(r, extras: false)));
  });

  testWidgets(
    'unified food menu scrolls on a small Arabic screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await pumpDay(tester, arabic: true);
        final context = tester.element(find.byType(DayTimelinePage));
        final t = AppLocalizations.of(context);
        await tap(tester, find.text(t.translate('day_timeline_log_food')));
        await tap(
          tester,
          find.widgetWithText(ListTile, t.translate('calendar_bulk_title')),
        );
        expect(find.byType(CalendarBulkSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => MockClient((r) async => read(r)));
    },
  );
}
