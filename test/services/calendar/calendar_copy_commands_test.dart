import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';

import 'calendar_food_commands_test.dart' show foodJson, committed;

Map<String, dynamic> copyFoodJson({String kind = 'meal'}) => {
  ...foodJson(kind: kind),
  'capabilities': ['edit_time', 'copy'],
  'overrides': [650, 40, 70, 20],
  'items': [
    {
      'id': 1,
      'item_key': '00000000-0000-4000-8000-000000000001',
      'name': 'Rice',
      'calories': 200,
    },
    {
      'id': 2,
      'item_key': '00000000-0000-4000-8000-000000000002',
      'name': 'Egg',
      'calories': 80,
    },
  ],
};

List<Map<String, dynamic>> destinations() => [
  {
    'scheduled_date': '2026-01-06',
    'scheduled_at': '2026-01-06T12:00:00+02:00',
    'expected_status': 'logged',
  },
  {
    'scheduled_date': '2090-01-07',
    'scheduled_at': '2090-01-07T12:00:00+02:00',
    'expected_status': 'planned',
  },
];

Future<void> copy({List<int>? itemIds, List<Map<String, dynamic>>? dates}) =>
    CalendarFoodCommands.copy(
      userId: 42,
      state: CalendarFoodState.fromJson(copyFoodJson()),
      timezone: 'Asia/Beirut',
      destinations: dates ?? destinations(),
      itemIds: itemIds,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'diet_meals_cache_u42_2026-01-05_rest';
  const actual = 'diet_meals_cache_u42_2026-01-06_rest';
  const planned = 'diet_meals_cache_u42_2090-01-07_rest';
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 42,
      source: '{}',
      actual: '{}',
      planned: '{}',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'copy refreshes consumed destinations only and never its untouched source',
    () async {
      final before = AccountStorage.dietChange.value;
      await http.runWithClient(
        () => copy(itemIds: [2]),
        () => MockClient((request) async {
          expect(request.url.path, endsWith('/food/copy'));
          final body = jsonDecode(request.body) as Map;
          expect(body['item_ids'], [2]);
          expect(body.containsKey('calories'), isFalse);
          expect((await CalendarFoodCommands.pending(42))!.isCopy, isTrue);
          return committed(request);
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(source), isTrue);
      expect(prefs.containsKey(actual), isFalse);
      expect(prefs.containsKey(planned), isTrue);
      expect(AccountStorage.dietChange.value, before + 1);
    },
  );
  test(
    'future-only copy leaves all consumed caches and signals unchanged',
    () async {
      final before = AccountStorage.dietChange.value;
      await http.runWithClient(
        () => copy(dates: [destinations().last]),
        () => MockClient((r) async => committed(r)),
      );
      expect(AccountStorage.dietChange.value, before);
      expect(
        (await SharedPreferences.getInstance()).containsKey(source),
        isTrue,
      );
    },
  );
  test(
    'copy receipt restores action, destinations and exact bytes for retry',
    () async {
      final bodies = <String>[];
      await http.runWithClient(
        () async {
          await expectLater(copy(), throwsA(isA<http.ClientException>()));
          final receipt = await CalendarFoodCommands.pending(42);
          expect(receipt!.action, 'copy');
          expect(receipt.destinations, hasLength(2));
          await expectLater(copy(), throwsA(isA<CalendarCommandError>()));
          await CalendarFoodCommands.retry(42);
        },
        () => MockClient((r) async {
          expect(r.url.path, endsWith('/food/copy'));
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('response lost');
          return committed(r);
        }),
      );
      expect(bodies, hasLength(2));
      expect(bodies.first, bodies.last);
    },
  );
  test('any pending destination blocks the entire multi-date copy', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'diet_action_queue_u42',
      jsonEncode([
        {'meal_date': '2090-01-07', 'type': 'updateMeal'},
      ]),
    );
    await http.runWithClient(
      () async {
        await expectLater(copy(), throwsA(isA<CalendarCommandError>()));
      },
      () => MockClient((_) async {
        fail('No request expected');
      }),
    );
    expect(await CalendarFoodCommands.pending(42), isNull);
  });
  test('pre-copy-version move receipts still decode as reschedule', () {
    final receipt = PendingCalendarMove.fromJson({
      'title': 'Old',
      'source_date': '2026-01-05',
      'request': jsonEncode({
        'source': {'kind': 'meal', 'id': 1},
        'scheduled_date': '2026-01-06',
      }),
    });
    expect(receipt.action, 'reschedule');
    expect(receipt.destinationDate, DateTime(2026, 1, 6));
  });
}
