import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/services/core/day_cache.dart';

void main() {
  final day = DateTime(2026, 11, 20);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('write is readable from memory and survives a fresh instance', () async {
    final cache = DayCache('test_day_v1');
    expect(await cache.read(1, day), isNull);
    await cache.write(1, day, {'a': 1});
    expect((await cache.read(1, day))!.json, {'a': 1});

    final restarted = DayCache('test_day_v1');
    expect((await restarted.read(1, day))!.json, {'a': 1});
    expect(await restarted.read(2, day), isNull, reason: 'scoped per user');
  });

  test('a stored null is a hit, distinct from never loaded', () async {
    final cache = DayCache('test_day_v1');
    await cache.write(1, day, null);
    final entry = await cache.read(1, day);
    expect(entry, isNotNull);
    expect(entry!.json, isNull);
  });

  test('evicts oldest persisted days beyond the limit', () async {
    final cache = DayCache('test_day_v1', persistentLimit: 2);
    for (var i = 1; i <= 3; i++) {
      await cache.write(1, DateTime(2026, 11, i), {'d': i});
    }
    final restarted = DayCache('test_day_v1', persistentLimit: 2);
    expect(await restarted.read(1, DateTime(2026, 11, 1)), isNull);
    expect((await restarted.read(1, DateTime(2026, 11, 3)))!.json, {'d': 3});
  });

  test('concurrent loads of one day share a single request', () async {
    final cache = DayCache('test_day_v1');
    var calls = 0;
    final gate = Completer<int>();
    Future<int> load() {
      calls++;
      return gate.future;
    }

    final a = cache.dedupe(1, day, load);
    final b = cache.dedupe(1, day, load);
    gate.complete(7);
    expect(await a, 7);
    expect(await b, 7);
    expect(calls, 1);
  });

  test('invalidate removes memory and disk copies', () async {
    final cache = DayCache('test_day_v1');
    await cache.write(1, day, {'a': 1});
    await cache.invalidate(1, day);
    expect(await cache.read(1, day), isNull);
    expect(await DayCache('test_day_v1').read(1, day), isNull);
  });
}
