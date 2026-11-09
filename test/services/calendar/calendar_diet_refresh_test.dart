import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/services/calendar/calendar_diet_refresh.dart';
import 'package:taqaproject/services/calendar/day_timeline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final day = DateTime(2026, 1, 5, 12);
  const affected = 'diet_meals_cache_u42_2026-01-05_rest';
  const training = 'diet_meals_cache_u42_2026-01-05_t9';
  const summary = 'diet_day_summary_cache_u42_2026-01-05';
  const otherDay = 'diet_meals_cache_u42_2026-01-06_rest';
  const otherUser = 'diet_meals_cache_u43_2026-01-05_rest';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 42,
      affected: '{}',
      training: '{}',
      summary: '{}',
      otherDay: '{}',
      otherUser: '{}',
      'diet_meals_last_sync_u42_2026-01-05_t9': 'old',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'committed changes invalidate only affected user/date variants and notify',
    () async {
      final before = AccountStorage.dietChange.value;
      await CalendarDietRefresh.afterConsumedChange(
        userId: 42,
        dates: [day, day],
      );
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        affected,
        training,
        summary,
        'diet_meals_last_sync_u42_2026-01-05_t9',
      ]) {
        expect(prefs.containsKey(key), isFalse);
      }
      expect(prefs.containsKey(otherDay), isTrue);
      expect(prefs.containsKey(otherUser), isTrue);
      expect(AccountStorage.dietChange.value, before + 1);
    },
  );

  test('pending offline projections and queue remain intact', () async {
    final prefs = await SharedPreferences.getInstance();
    final queued = jsonEncode([
      {'meal_date': '2026-01-05', 'type': 'manualEntry'},
    ]);
    await prefs.setString('diet_action_queue_u42', queued);
    await CalendarDietRefresh.afterConsumedChange(userId: 42, dates: [day]);
    expect(prefs.containsKey(affected), isTrue);
    expect(prefs.containsKey(training), isTrue);
    expect(prefs.containsKey(summary), isTrue);
    expect(prefs.getString('diet_action_queue_u42'), queued);
  });

  test('an account change cannot send a refresh to the new account', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', 43);
    final before = AccountStorage.dietChange.value;
    await CalendarDietRefresh.afterConsumedChange(userId: 42, dates: [day]);
    expect(AccountStorage.dietChange.value, before);
    expect(prefs.containsKey(otherUser), isTrue);
  });

  for (final status in ['logged', 'planned', 'already_completed', 'failure']) {
    test(
      'meal creation refreshes consumed data only after success: $status',
      () async {
        final before = AccountStorage.dietChange.value;
        await http.runWithClient(
          () async {
            final save = DayTimelineService.createMeal(
              userId: 42,
              scheduledAt: day,
              title: 'Lunch',
              items: [
                {'name': 'Rice', 'calories': 200},
              ],
              entryKey: 'test-entry-key',
            );
            if (status == 'failure') {
              await expectLater(save, throwsException);
            } else {
              expect((await save)['status'], status);
            }
          },
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({'status': status}),
              status == 'failure' ? 500 : 200,
            ),
          ),
        );
        final consumed = status == 'logged' || status == 'already_completed';
        expect(AccountStorage.dietChange.value, before + (consumed ? 1 : 0));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(affected), !consumed);
      },
    );
  }

  test('photo logging uses the same consumed-food refresh path', () async {
    final before = AccountStorage.dietChange.value;
    await http.runWithClient(
      () async {
        final result = await DayTimelineService.createPhotoMeal(
          userId: 42,
          scheduledAt: day,
          photoBytes: [1, 2, 3],
          filename: 'meal.jpg',
          entryKey: 'photo-entry-key',
        );
        expect(result['status'], 'logged');
      },
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/meals/photo'));
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        return http.Response(jsonEncode({'status': 'logged'}), 200);
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(affected), isFalse);
    expect(AccountStorage.dietChange.value, before + 1);
  });

  test('mark eaten refreshes the selected logical date', () async {
    await http.runWithClient(
      () async {
        await DayTimelineService.markMealPlanEaten(
          userId: 42,
          planId: 7,
          date: day,
        );
      },
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/meal-plans/7/complete'));
        return http.Response(jsonEncode({'status': 'logged'}), 200);
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(affected), isFalse);
    expect(prefs.containsKey(otherDay), isTrue);
  });
}
