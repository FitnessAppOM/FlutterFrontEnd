import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/services/calendar/calendar_bulk_selection.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'package:taqaproject/services/calendar/calendar_time_zone.dart';
import 'calendar_copy_commands_test.dart' show copyFoodJson;
import 'calendar_food_commands_test.dart' show committed;

Map<String, dynamic> bulkFoodJson({
  int id = 12,
  String kind = 'meal',
  String day = '2026-01-05',
  String? at = '2026-01-05T10:00:00Z',
}) => {
  ...copyFoodJson(kind: kind),
  'source': {'id': id, 'kind': kind, 'revision': 'a' * 64},
  'title': 'Meal $id',
  'entry_date': day,
  'scheduled_at': at,
  'capabilities': ['edit_time', 'copy', 'bulk'],
  'overrides': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'diet_meals_cache_u42_2026-01-05_rest';
  const planDay = 'diet_meals_cache_u42_2026-01-07_rest';
  const destination = 'diet_meals_cache_u42_2026-01-06_rest';
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 42,
      source: '{}',
      destination: '{}',
      planDay: '{}',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });
  CalendarFoodState food({
    int id = 12,
    String kind = 'meal',
    String day = '2026-01-05',
    String? at = '2026-01-05T10:00:00Z',
  }) => CalendarFoodState.fromJson(
    bulkFoodJson(id: id, kind: kind, day: day, at: at),
  );
  List<Map<String, dynamic>> entries(
    CalendarBulkSelection selection,
    List<CalendarFoodState> states, {
    String action = 'copy',
    String zone = 'UTC',
    List<DateTime>? anchors,
  }) => selection.entries(
    states: states,
    action: action,
    zone: zone,
    anchors: anchors ?? [DateTime.utc(2026, 1, 6, 10)],
    previewNow: DateTime.utc(2026, 11, 9),
  );

  test(
    'parent replaces child choices and removing one child retains others',
    () {
      final s = food();
      final selection = CalendarBulkSelection();
      selection.selectItem(s, '1', true);
      expect(selection.count, 1);
      selection.selectWhole(s, true);
      expect(entries(selection, [s]).single.containsKey('item_ids'), false);
      selection.selectItem(s, '1', false);
      expect(entries(selection, [s]).single['item_ids'], [2]);
      selection.selectWhole(s, true);
      expect(selection.hasItems, false);
    },
  );
  test(
    'batch shifts preserve elapsed spacing and seconds across DST and midnight',
    () {
      final first = food(at: '2026-01-05T10:00:12Z');
      final second = food(id: 13, at: '2026-01-05T13:30:39Z');
      final selection = CalendarBulkSelection()
        ..selectWhole(first, true)
        ..selectWhole(second, true);
      final anchor = CalendarTimeZone.candidates(
        DateTime(2026, 3, 8),
        0,
        30,
        'America/New_York',
      ).single;
      final result = entries(
        selection,
        [first, second],
        action: 'reschedule',
        zone: 'America/New_York',
        anchors: [anchor],
      );
      final a = DateTime.parse(result[0]['destinations'][0]['scheduled_at']);
      final b = DateTime.parse(result[1]['destinations'][0]['scheduled_at']);
      expect(
        b.difference(a),
        second.scheduledAt!.difference(first.scheduledAt!),
      );
      expect(
        result[1]['destinations'][0]['scheduled_at'],
        contains('05:00:27'),
      );
      final midnight = entries(
        selection,
        [first, second],
        anchors: [DateTime.utc(2026, 1, 6, 23)],
      );
      expect(midnight[1]['destinations'][0]['scheduled_date'], '2026-01-07');
    },
  );
  test(
    'selected plans use stable keys and reload drops disappeared children',
    () {
      final plan = food(kind: 'meal_plan');
      final selection = CalendarBulkSelection();
      final key = plan.items.first['item_key'] as String;
      selection.selectItem(plan, key, true);
      expect(entries(selection, [plan]).single['item_keys'], [key]);
      final changed = CalendarFoodState.fromJson({
        ...bulkFoodJson(kind: 'meal_plan'),
        'items': [plan.items.last],
      });
      selection.retain([changed]);
      expect(selection.count, 0);
    },
  );
  test(
    'item moves, untimed moves, and ambiguous override deletes are blocked',
    () {
      final s = food();
      final selection = CalendarBulkSelection()..selectItem(s, '1', true);
      expect(
        () => entries(selection, [s], action: 'reschedule'),
        throwsA(isA<CalendarCommandError>()),
      );
      final overridden = CalendarFoodState.fromJson({
        ...bulkFoodJson(),
        'overrides': [650, null, null, null],
      });
      expect(
        () => entries(selection, [overridden], action: 'delete'),
        throwsA(isA<CalendarCommandError>()),
      );
      final untimed = food(at: null);
      selection.selectWhole(untimed, true);
      expect(
        () => entries(selection, [untimed], action: 'reschedule'),
        throwsA(isA<CalendarCommandError>()),
      );
      expect(entries(selection, [untimed]).single['destinations'], isNotEmpty);
    },
  );
  test(
    'delete recovery preserves exact bytes and excludes planned dates from consumed refresh',
    () async {
      final states = [
        food(),
        food(id: 13, kind: 'meal_plan', day: '2026-01-07'),
      ];
      final selection = CalendarBulkSelection();
      for (final s in states) {
        selection.selectWhole(s, true);
      }
      final bodies = <String>[];
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarFoodCommands.bulk(
              userId: 42,
              action: 'delete',
              timezone: 'UTC',
              entries: entries(selection, states, action: 'delete'),
              states: states,
            ),
            throwsA(isA<http.ClientException>()),
          );
          final pending = await CalendarFoodCommands.pending(42);
          expect(pending!.isBulk, true);
          expect(pending.destinations, isEmpty);
          expect(pending.sourceDates.length, 2);
          await CalendarFoodCommands.retry(42);
        },
        () => MockClient((r) async {
          expect(r.url.path, endsWith('/food/bulk'));
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('response lost');
          return committed(r);
        }),
      );
      expect(bodies[0], bodies[1]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(source), false);
      expect(prefs.containsKey(planDay), true);
      expect(prefs.containsKey(destination), true);
      expect(await CalendarFoodCommands.pending(42), isNull);
    },
  );
  test('bulk copy refreshes logged destinations only', () async {
    final states = [food(), food(id: 13, at: '2026-01-05T14:00:00Z')];
    final selection = CalendarBulkSelection();
    for (final s in states) {
      selection.selectWhole(s, true);
    }
    await http.runWithClient(
      () => CalendarFoodCommands.bulk(
        userId: 42,
        action: 'copy',
        timezone: 'UTC',
        entries: entries(selection, states),
        states: states,
      ),
      () => MockClient((r) async => committed(r)),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(source), true);
    expect(prefs.containsKey(destination), false);
  });
  test('planned-only delete emits no consumed notification', () async {
    final s = food(kind: 'meal_plan');
    final selection = CalendarBulkSelection()..selectWhole(s, true);
    final before = AccountStorage.dietChange.value;
    await http.runWithClient(
      () => CalendarFoodCommands.bulk(
        userId: 42,
        action: 'delete',
        timezone: 'UTC',
        entries: entries(selection, [s], action: 'delete'),
        states: [s],
      ),
      () => MockClient((r) async => committed(r)),
    );
    expect(AccountStorage.dietChange.value, before);
  });
  test(
    'offline edits on any source block even destination-free deletes',
    () async {
      final states = [food(), food(id: 13, day: '2026-01-07')];
      final selection = CalendarBulkSelection();
      for (final s in states) {
        selection.selectWhole(s, true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'diet_action_queue_u42',
        jsonEncode([
          {'type': 'updateMeal', 'meal_date': '2026-01-07'},
        ]),
      );
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarFoodCommands.bulk(
              userId: 42,
              action: 'delete',
              timezone: 'UTC',
              entries: entries(selection, states, action: 'delete'),
              states: states,
            ),
            throwsA(isA<CalendarCommandError>()),
          );
        },
        () => MockClient((_) async {
          fail('Must not submit with pending Diet edits');
        }),
      );
      expect(await CalendarFoodCommands.pending(42), isNull);
    },
  );
}
