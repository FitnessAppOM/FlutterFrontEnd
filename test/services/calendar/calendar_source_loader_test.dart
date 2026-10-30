import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/calendar/calendar_source_loader.dart';

void main() {
  test('keeps populated source data for an existing user', () async {
    final result = await CalendarSourceLoader.load<List<int>>(
      source: 'meals',
      request: () async => [1, 2],
      fallback: const [],
    );

    expect(result, [1, 2]);
  });

  test('keeps empty source data valid for a new user', () async {
    final result = await CalendarSourceLoader.load<List<int>>(
      source: 'training',
      request: () async => const [],
      fallback: const [-1],
    );

    expect(result, isEmpty);
  });

  test('one failed source falls back without breaking the month', () async {
    String? failedSource;
    final results = await Future.wait<List<int>>([
      CalendarSourceLoader.load(
        source: 'training',
        request: () async => [7],
        fallback: const [],
      ),
      CalendarSourceLoader.load(
        source: 'meals',
        request: () async => throw Exception('temporary failure'),
        fallback: const [],
        onFailure: (source, _, _) => failedSource = source,
      ),
      CalendarSourceLoader.load(
        source: 'sleep',
        request: () async => [9],
        fallback: const [],
      ),
    ]);

    expect(results, [
      [7],
      <int>[],
      [9],
    ]);
    expect(failedSource, 'meals');
  });
}
