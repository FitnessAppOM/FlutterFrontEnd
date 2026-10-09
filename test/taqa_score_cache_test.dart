import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/services/scores/taqa_score_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TaqaScoreApi.clearCache();
  });

  test(
    'daily score survives memory cache reset and stays user scoped',
    () async {
      final date = DateTime(2026, 10, 8);
      final score = TaqaDailyScore(
        userId: 42,
        entryDate: date,
        provider: 'whoop',
        taqaValueScore: 81,
        sleep: const TaqaSubScore(
          score: 78,
          path: 'wearable',
          details: <String, dynamic>{'efficiency': 0.91},
        ),
        recovery: const TaqaSubScore(score: 84, path: 'wearable'),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'taqa_score_cache_v1_42_2026-10-08',
        jsonEncode(<String, dynamic>{
          'cached_at_ms': DateTime(2026, 10, 9).millisecondsSinceEpoch,
          'score': score.toJson(),
        }),
      );

      TaqaScoreApi.clearCache();
      final restored = await TaqaScoreApi.readCachedDaily(
        userId: 42,
        date: date,
      );
      final otherUser = await TaqaScoreApi.readCachedDaily(
        userId: 7,
        date: date,
      );

      expect(restored?.userId, 42);
      expect(restored?.taqaValueScore, 81);
      expect(restored?.sleep.score, 78);
      expect(restored?.sleep.details['efficiency'], 0.91);
      expect(otherUser, isNull);
    },
  );
}
