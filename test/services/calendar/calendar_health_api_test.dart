import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/services/calendar/calendar_health_api.dart';
import 'package:taqaproject/services/calendar/calendar_food_commands.dart';
import 'package:taqaproject/services/core/network_status_service.dart';

Map<String, dynamic> healthSession({String kind = 'sleep'}) => {
  'source': {'id': 9, 'revision': 2},
  'kind': kind,
  'entry_date': '2026-01-05',
  'started_at': kind == 'sleep'
      ? '2026-01-04T23:00:00Z'
      : '2026-01-05T12:00:00Z',
  'ended_at': kind == 'sleep' ? '2026-01-05T07:00:00Z' : '2026-01-05T13:00:00Z',
  'timezone': 'UTC',
  'sleep_kind': kind == 'sleep' ? 'main' : null,
  'activity_kind': kind == 'activity' ? 'walk' : null,
  'distance_km': null,
  'duration_seconds': kind == 'sleep' ? 28800 : 3600,
  'capabilities': ['update', 'delete'],
  'source_provider': 'manual',
};
Map<String, dynamic> healthDay({
  List<Map<String, dynamic>> sessions = const [],
}) => {
  'entry_date': '2026-01-05',
  'sessions': sessions,
  'capabilities': ['create_activity', 'create_sleep'],
  'sleep_summary': {
    'origin': 'manual_sessions',
    'minutes': 480,
    'manual_sessions_used': true,
    'manual_duration_seconds': 28800,
  },
};
http.Response healthCommitted(http.Request r) => http.Response(
  jsonEncode({
    'status': 'committed',
    'operation_key': jsonDecode(r.body)['operation_key'],
    'affected_dates': ['2026-01-05'],
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    NetworkStatusService.instance.reportServerReached();
    SharedPreferences.setMockInitialValues({
      'user_id': 42,
      'diet_meals_cache_u42_2026-01-05_rest': 'keep',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });
  final request = {
    'action': 'delete',
    'source': {'id': 9, 'revision': 2},
  };
  test(
    'response loss retains exact retry, replay does not touch Diet',
    () async {
      final bodies = <String>[];
      final before = AccountStorage.dietChange.value;
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarHealthApi.submit(42, request),
            throwsA(isA<http.ClientException>()),
          );
          expect(await CalendarHealthApi.pending(42), isNotNull);
          await expectLater(
            CalendarHealthApi.submit(42, request),
            throwsA(isA<CalendarCommandError>()),
          );
          await CalendarHealthApi.retry(42);
        },
        () => MockClient((r) async {
          bodies.add(r.body);
          if (bodies.length == 1) throw http.ClientException('lost response');
          return healthCommitted(r);
        }),
      );
      expect(bodies.length, 2);
      expect(bodies.first, bodies.last);
      expect(await CalendarHealthApi.pending(42), isNull);
      expect(AccountStorage.dietChange.value, before);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'diet_meals_cache_u42_2026-01-05_rest',
        ),
        'keep',
      );
    },
  );
  test(
    'delete preview persists locally while the server receives only its strict command',
    () async {
      final bodies = <String>[];
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarHealthApi.submit(42, request, preview: healthSession()),
            throwsA(isA<http.ClientException>()),
          );
          expect(
            (await CalendarHealthApi.pending(42))!['_preview'],
            healthSession(),
          );
          await CalendarHealthApi.retry(42);
        },
        () => MockClient((r) async {
          bodies.add(r.body);
          expect((jsonDecode(r.body) as Map).containsKey('_preview'), false);
          if (bodies.length == 1) throw http.ClientException('lost');
          return healthCommitted(r);
        }),
      );
      expect(bodies.first, bodies.last);
    },
  );
  for (final status in [409, 422, 404, 503, 401]) {
    test('receipt classification for HTTP $status', () async {
      await http.runWithClient(() async {
        await expectLater(
          CalendarHealthApi.submit(42, request),
          throwsA(isA<CalendarCommandError>()),
        );
      }, () => MockClient((r) async => http.Response('{}', status)));
      expect(
        await CalendarHealthApi.pending(42),
        status == 409 || status == 422 ? isNull : isNotNull,
      );
    });
  }
  test('missing source is definitive, unavailable route is not', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          CalendarHealthApi.submit(42, request),
          throwsA(isA<CalendarCommandError>()),
        );
      },
      () => MockClient(
        (r) async =>
            http.Response('{"detail":"Manual session not found"}', 404),
      ),
    );
    expect(await CalendarHealthApi.pending(42), isNull);
  });
  test('old backend is optional and range uses local dates', () async {
    final paths = <Uri>[];
    await http.runWithClient(
      () async {
        expect(await CalendarHealthApi.day(42, DateTime(2026, 1, 5)), isNull);
        expect(
          await CalendarHealthApi.range(
            42,
            DateTime(2026, 1),
            DateTime(2026, 1, 31),
          ),
          isNull,
        );
      },
      () => MockClient((r) async {
        paths.add(r.url);
        return http.Response('{}', 404);
      }),
    );
    expect(paths.last.queryParameters, {
      'start': '2026-01-01',
      'end': '2026-01-31',
    });
  });
  test('offline guard preserves receipt and does not send', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'calendar_pending_health_u42',
      jsonEncode({'operation_key': 'offline-session-1', ...request}),
    );
    NetworkStatusService.instance.reportNetworkFailure(
      const SocketException('No network connection'),
    );
    await http.runWithClient(
      () async {
        await expectLater(
          CalendarHealthApi.retry(42),
          throwsA(isA<CalendarCommandError>()),
        );
      },
      () => MockClient((_) async {
        fail('Offline writes must not send');
      }),
    );
    expect(
      (await CalendarHealthApi.pending(42))!['operation_key'],
      'offline-session-1',
    );
    NetworkStatusService.instance.reportServerReached();
  });
  test(
    'a response for the previous account cannot populate the new account',
    () async {
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarHealthApi.day(42, DateTime(2026, 1, 5)),
            throwsA(isA<CalendarCommandError>()),
          );
        },
        () => MockClient((_) async {
          await (await SharedPreferences.getInstance()).setInt('user_id', 99);
          return http.Response(
            jsonEncode(healthDay(sessions: [healthSession()])),
            200,
          );
        }),
      );
    },
  );
  test(
    'malformed optional data fails before it reaches timeline widgets',
    () async {
      await http.runWithClient(() async {
        await expectLater(
          CalendarHealthApi.day(42, DateTime(2026, 1, 5)),
          throwsFormatException,
        );
      }, () => MockClient((_) async => http.Response('{"sessions":[]}', 200)));
    },
  );
  test(
    'account mismatch sends nothing and cannot retry another account receipt',
    () async {
      await http.runWithClient(
        () async {
          await expectLater(
            CalendarHealthApi.submit(99, request),
            throwsA(isA<CalendarCommandError>()),
          );
          await expectLater(
            CalendarHealthApi.retry(99),
            throwsA(isA<CalendarCommandError>()),
          );
        },
        () => MockClient((_) async {
          fail('Must not send');
        }),
      );
      expect(await CalendarHealthApi.pending(99), isNull);
    },
  );
  test('two simultaneous submits cannot create two requests', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    var posts = 0;
    await http.runWithClient(
      () async {
        final first = CalendarHealthApi.submit(42, request);
        await started.future;
        await expectLater(
          CalendarHealthApi.submit(42, request),
          throwsA(isA<CalendarCommandError>()),
        );
        final stored = await CalendarHealthApi.pending(42);
        response.complete(
          http.Response(
            jsonEncode({
              'status': 'committed',
              'operation_key': stored!['operation_key'],
            }),
            200,
          ),
        );
        await first;
      },
      () => MockClient((r) {
        posts++;
        started.complete();
        return response.future;
      }),
    );
    expect(posts, 1);
  });
}
