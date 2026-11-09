import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'package:taqaproject/services/calendar/calendar_time_zone.dart';

Map<String, dynamic> foodJson({String kind = 'meal'}) => {
  'source': {'kind': kind, 'id': 12, 'revision': 'a' * 64},
  'entry_date': '2026-01-05',
  'scheduled_at': '2026-01-05T10:00:00Z',
  'title': 'Lunch',
  'capabilities': ['edit_time'],
};

Future<void> move({String kind = 'meal'}) => CalendarFoodCommands.move(
  userId: 42,
  state: CalendarFoodState.fromJson(foodJson(kind: kind)),
  timestamp: '2026-01-06T12:30:00+02:00',
  timezone: 'Asia/Beirut',
  destination: DateTime(2026, 1, 6),
);

http.Response committed(http.Request request) => http.Response(
  jsonEncode({
    'status': 'committed',
    'operation_key': jsonDecode(request.body)['operation_key'],
    'affected_dates': ['2026-01-05', '2026-01-06'],
    'replayed': false,
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sourceCache = 'diet_meals_cache_u42_2026-01-05_rest';
  const destinationCache = 'diet_meals_cache_u42_2026-01-06_rest';
  const otherCache = 'diet_meals_cache_u42_2026-01-07_rest';
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 42,
      sourceCache: '{}',
      destinationCache: '{}',
      otherCache: '{}',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'committed whole meal move refreshes both dates, preserves unrelated cache',
    () async {
      final before = AccountStorage.dietChange.value;
      await http.runWithClient(
        () => move(),
        () => MockClient((request) async {
          final pending = await CalendarFoodCommands.pending(42);
          expect(
            pending!.encodedRequest,
            request.body,
          ); // Stored before network send.
          expect(jsonDecode(request.body)['source'], foodJson()['source']);
          expect(request.url.path, endsWith('/calendar/42/food/reschedule'));
          return committed(request);
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(sourceCache), isFalse);
      expect(prefs.containsKey(destinationCache), isFalse);
      expect(prefs.containsKey(otherCache), isTrue);
      expect(AccountStorage.dietChange.value, before + 1);
      expect(await CalendarFoodCommands.pending(42), isNull);
    },
  );

  test(
    'response loss retains exact request through reload and retry',
    () async {
      final bodies = <String>[];
      await http.runWithClient(
        () async {
          await expectLater(move(), throwsA(isA<http.ClientException>()));
          final restored = await CalendarFoodCommands.pending(42);
          expect(restored!.sourceDate, DateTime(2026, 1, 5));
          expect(restored.destinationDate, DateTime(2026, 1, 6));
          await expectLater(move(), throwsA(isA<CalendarCommandError>()));
          await CalendarFoodCommands.retry(42);
        },
        () => MockClient((request) async {
          bodies.add(request.body);
          if (bodies.length == 1) throw http.ClientException('response lost');
          return committed(request);
        }),
      );
      expect(bodies, hasLength(2));
      expect(bodies[0], bodies[1]);
      expect(await CalendarFoodCommands.pending(42), isNull);
    },
  );

  for (final date in ['2026-01-05', '2026-01-06']) {
    test(
      'pending offline edits on $date block before persistence/network',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'diet_action_queue_u42',
          jsonEncode([
            {'meal_date': date, 'type': 'updateMeal'},
          ]),
        );
        await http.runWithClient(
          () async {
            await expectLater(
              move(),
              throwsA(
                isA<CalendarCommandError>().having(
                  (e) => e.messageKey,
                  'message',
                  'calendar_time_pending_diet',
                ),
              ),
            );
          },
          () => MockClient((_) async {
            fail('Must not submit');
          }),
        );
        expect(await CalendarFoodCommands.pending(42), isNull);
        expect(prefs.containsKey(sourceCache), isTrue);
        expect(prefs.containsKey(destinationCache), isTrue);
      },
    );
  }

  test(
    'plan move never changes consumed caches or nutrition notifications',
    () async {
      final before = AccountStorage.dietChange.value;
      await http.runWithClient(
        () => move(kind: 'meal_plan'),
        () => MockClient((r) async => committed(r)),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(sourceCache), isTrue);
      expect(prefs.containsKey(destinationCache), isTrue);
      expect(AccountStorage.dietChange.value, before);
    },
  );

  test('conflict clears rejected receipt and requires fresh state', () async {
    await http.runWithClient(() async {
      await expectLater(
        move(),
        throwsA(
          isA<CalendarCommandError>().having((e) => e.reload, 'reload', isTrue),
        ),
      );
    }, () => MockClient((_) async => http.Response('{}', 409)));
    expect(await CalendarFoodCommands.pending(42), isNull);
    expect(
      (await SharedPreferences.getInstance()).containsKey(sourceCache),
      isTrue,
    );
  });

  test(
    'server failure retains receipt while disabled/old state endpoints hide capability',
    () async {
      await http.runWithClient(
        () async {
          expect(await CalendarFoodCommands.fetchState(42, 'meal', 12), isNull);
          await expectLater(move(), throwsA(isA<CalendarCommandError>()));
          expect(await CalendarFoodCommands.pending(42), isNotNull);
        },
        () => MockClient(
          (r) async => http.Response('{}', r.method == 'GET' ? 503 : 500),
        ),
      );
    },
  );

  test(
    'account switch blocks submission and cannot replay another account receipt',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', 43);
      await http.runWithClient(
        () async {
          await expectLater(move(), throwsA(isA<CalendarCommandError>()));
          await expectLater(
            CalendarFoodCommands.retry(42),
            throwsA(isA<CalendarCommandError>()),
          );
        },
        () => MockClient((_) async {
          fail('Must not submit');
        }),
      );
      expect(await CalendarFoodCommands.pending(43), isNull);
    },
  );

  test('rapid concurrent saves send only one request', () async {
    final sent = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    await http.runWithClient(
      () async {
        final first = move();
        await sent.future;
        await expectLater(move(), throwsA(isA<CalendarCommandError>()));
        release.complete();
        await first;
      },
      () => MockClient((request) async {
        calls++;
        sent.complete();
        await release.future;
        return committed(request);
      }),
    );
    expect(calls, 1);
  });

  test(
    'DST gap is rejected and repeated time has two distinct explicit offsets',
    () {
      expect(
        CalendarTimeZone.candidates(
          DateTime(2026, 3, 8),
          2,
          30,
          'America/New_York',
        ),
        isEmpty,
      );
      final fold = CalendarTimeZone.candidates(
        DateTime(2026, 11, 1),
        1,
        30,
        'America/New_York',
      );
      expect(fold, hasLength(2));
      expect(fold.map(CalendarTimeZone.timestamp), [
        '2026-11-01T01:30:00-04:00',
        '2026-11-01T01:30:00-05:00',
      ]);
    },
  );

  test(
    'missing route retains uncertain receipt; missing owned source rejects it',
    () async {
      var detail = 'Not Found';
      await http.runWithClient(
        () async {
          await expectLater(move(), throwsA(isA<CalendarCommandError>()));
          expect(await CalendarFoodCommands.pending(42), isNotNull);
          detail = 'Food entry not found';
          await expectLater(
            CalendarFoodCommands.retry(42),
            throwsA(
              isA<CalendarCommandError>().having(
                (e) => e.reload,
                'reload',
                isTrue,
              ),
            ),
          );
          expect(await CalendarFoodCommands.pending(42), isNull);
        },
        () => MockClient(
          (_) async => http.Response(jsonEncode({'detail': detail}), 404),
        ),
      );
    },
  );

  test('destination offset uses the selected date, not the current date', () {
    final winter = CalendarTimeZone.candidates(
      DateTime(2026, 1, 5),
      12,
      30,
      'Asia/Beirut',
    ).single;
    final summer = CalendarTimeZone.candidates(
      DateTime(2026, 7, 5),
      12,
      30,
      'Asia/Beirut',
    ).single;
    expect(CalendarTimeZone.timestamp(winter), '2026-01-05T12:30:00+02:00');
    expect(CalendarTimeZone.timestamp(summer), '2026-07-05T12:30:00+03:00');
  });
}
