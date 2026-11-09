import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'package:taqaproject/services/calendar/calendar_portion_math.dart';
import 'calendar_bulk_commands_test.dart' show bulkFoodJson;
import 'calendar_food_commands_test.dart' show committed;

Map<String, dynamic> detailsFoodJson({String kind = 'meal'}) => {
  ...bulkFoodJson(kind: kind),
  'capabilities': [
    'edit_time',
    'copy',
    'bulk',
    'create_recipe',
    'edit_contents',
  ],
  'overrides': [650, 40, 70, 20],
};
Map<String, dynamic> recipeJson() => {
  'id': 5,
  'name': 'Rice recipe',
  'revision': 'b' * 64,
  'servings': 4,
  'prepared_weight_g': 800,
  'items': detailsFoodJson()['items'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'diet_meals_cache_u42_2026-01-05_rest';
  const destination = 'diet_meals_cache_u42_2026-01-06_rest';
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 42,
      source: '{}',
      destination: '{}',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'portion math rounds positive halves exactly and validates decimal precision',
    () {
      expect(CalendarPortionMath.rounded(5, 500, 1000), 3);
      expect(CalendarPortionMath.rounded(35, 500, 4000), 4);
      expect(CalendarPortionMath.units('0.125'), 125);
      for (final value in ['NaN', '1e3', '1.0001', '-1', '1001']) {
        expect(CalendarPortionMath.units(value), isNull);
      }
    },
  );
  test(
    'recipe save retains an exact request after response loss and never refreshes food',
    () async {
      final state = CalendarFoodState.fromJson(detailsFoodJson());
      final before = AccountStorage.dietChange.value;
      final bodies = <String>[];
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarFoodCommands.details(
              userId: 42,
              action: 'recipe',
              date: state.date,
              title: 'Recipe',
              states: [state],
              request: {
                'entries': [
                  {'source': state.source, 'destinations': []},
                ],
                'name': 'Recipe',
                'servings': '4',
                'nutrition_policy': 'item_totals',
              },
            ),
            throwsA(isA<http.ClientException>()),
          );
          final pending = await CalendarFoodCommands.pending(42);
          expect(pending!.destinations, isEmpty);
          expect(pending.kind, 'meal');
          expect(pending.isDetails, true);
          await CalendarFoodCommands.retry(42);
        },
        () => MockClient((r) async {
          expect(r.url.path, endsWith('/food/recipe'));
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('lost');
          return committed(r);
        }),
      );
      expect(bodies.first, bodies.last);
      expect(AccountStorage.dietChange.value, before);
      expect((await SharedPreferences.getInstance()).containsKey(source), true);
    },
  );
  test('recipe logging refreshes only the logged destination', () async {
    await http.runWithClient(
      () => CalendarFoodCommands.details(
        userId: 42,
        action: 'recipe-log',
        title: 'Recipe',
        date: DateTime(2026, 1, 5),
        request: {
          'recipe': {'id': 5, 'revision': 'b' * 64},
          'servings': '0.5',
          'timezone': 'UTC',
          'destination': {
            'scheduled_date': '2026-01-06',
            'scheduled_at': '2026-01-06T12:00:00Z',
            'expected_status': 'logged',
          },
        },
      ),
      () => MockClient((r) async => committed(r)),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(source), true);
    expect(prefs.containsKey(destination), false);
  });
  test('future recipe log never invalidates consumed caches', () async {
    final before = AccountStorage.dietChange.value;
    await http.runWithClient(
      () => CalendarFoodCommands.details(
        userId: 42,
        action: 'recipe-log',
        title: 'Recipe',
        date: DateTime(2026, 1, 5),
        request: {
          'recipe': {'id': 5, 'revision': 'b' * 64},
          'servings': '0.5',
          'timezone': 'UTC',
          'destination': {
            'scheduled_date': '2090-01-06',
            'scheduled_at': '2090-01-06T12:00:00Z',
            'expected_status': 'planned',
          },
        },
      ),
      () => MockClient((r) async => committed(r)),
    );
    expect(AccountStorage.dietChange.value, before);
  });
  test(
    'item edits refresh consumed source only; plan edits do not notify',
    () async {
      for (final kind in ['meal', 'meal_plan']) {
        final state = CalendarFoodState.fromJson(detailsFoodJson(kind: kind));
        final before = AccountStorage.dietChange.value;
        await http.runWithClient(
          () => CalendarFoodCommands.details(
            userId: 42,
            action: 'edit-item',
            title: 'Rice',
            date: state.date,
            states: [state],
            request: {
              'source': state.source,
              'item_id': 1,
              'quantity_multiplier': '0.5',
              'override_policy': 'preserve',
            },
          ),
          () => MockClient((r) async => committed(r)),
        );
        expect(
          AccountStorage.dietChange.value,
          before + (kind == 'meal' ? 1 : 0),
        );
      }
      expect(
        (await SharedPreferences.getInstance()).containsKey(destination),
        true,
      );
    },
  );
  test('explicit missing recipe response clears unresolved request', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          CalendarFoodCommands.details(
            userId: 42,
            action: 'recipe-log',
            title: 'Gone',
            date: DateTime(2026, 1, 5),
            request: {
              'recipe': {'id': 5, 'revision': 'b' * 64},
              'servings': '1',
              'timezone': 'UTC',
              'destination': {
                'scheduled_date': '2026-01-06',
                'scheduled_at': '2026-01-06T12:00:00Z',
                'expected_status': 'logged',
              },
            },
          ),
          throwsA(isA<CalendarCommandError>()),
        );
      },
      () => MockClient(
        (_) async =>
            http.Response(jsonEncode({'detail': 'Recipe not found'}), 404),
      ),
    );
    expect(await CalendarFoodCommands.pending(42), isNull);
  });
  test(
    'pending offline source edit prevents recipe snapshot submission',
    () async {
      final state = CalendarFoodState.fromJson(detailsFoodJson());
      await (await SharedPreferences.getInstance()).setString(
        'diet_action_queue_u42',
        jsonEncode([
          {'meal_date': '2026-01-05', 'type': 'updateMeal'},
        ]),
      );
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarFoodCommands.details(
              userId: 42,
              action: 'recipe',
              date: state.date,
              title: 'Recipe',
              states: [state],
              request: {
                'entries': [
                  {'source': state.source, 'destinations': []},
                ],
              },
            ),
            throwsA(isA<CalendarCommandError>()),
          );
        },
        () => MockClient((_) async {
          fail('Must not submit before offline edits synchronize');
        }),
      );
      expect(await CalendarFoodCommands.pending(42), isNull);
    },
  );
}
