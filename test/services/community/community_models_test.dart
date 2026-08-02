import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/community/community_models.dart';

void main() {
  test('CommunityBadge parses optional v2 progress fields', () {
    final badge = CommunityBadge.fromJson({
      'badge_key': 'century_club',
      'name': 'Century Club',
      'category': 'milestone',
      'description': 'Complete 100 workouts.',
      'is_earned': false,
      'progress_value': 63,
      'target_value': 100,
      'progress_percent': 63,
      'progress_unit': 'workouts',
      'rule_version': 2,
    });

    expect(badge.progressValue, 63);
    expect(badge.targetValue, 100);
    expect(badge.progressUnit, 'workouts');
    expect(badge.ruleVersion, 2);
  });

  test('CommunityChallenge parses rule metadata and weekly segments', () {
    final challenge = CommunityChallenge.fromJson({
      'challenge_id': 10,
      'name': 'Base Builder',
      'challenge_type': 'cardio_sessions',
      'challenge_key': 'base_builder',
      'rule_type': 'base_builder',
      'rule_config': {'weeks_required': 8, 'sessions_per_week': 4},
      'recurrence_type': 'weekly',
      'rule_version': 1,
      'is_active': true,
      'progress_value': 2,
      'progress_percent': 25,
      'is_completed': false,
      'muted_notifications': false,
      'scope': 'global',
      'segments': [
        {
          'segment_index': 0,
          'period_start': '2026-07-27',
          'period_end': '2026-08-02',
          'progress_value': 4,
          'target_value': 4,
          'is_completed': true,
          'metadata': {'sessions': 4},
        },
      ],
    });

    expect(challenge.displayRuleName, 'Base Builder');
    expect(challenge.segments, hasLength(1));
    expect(challenge.segments.single.isCompleted, isTrue);
    expect(challenge.segments.single.metadata['sessions'], 4);
  });

  test('CommunityChallenge remains compatible with legacy response', () {
    final challenge = CommunityChallenge.fromJson({
      'challenge_id': 11,
      'name': 'Legacy',
      'challenge_type': 'workout_days',
      'is_active': true,
      'progress_value': 1,
      'progress_percent': 10,
      'is_completed': false,
      'muted_notifications': false,
      'scope': 'global',
    });

    expect(challenge.ruleConfig, isEmpty);
    expect(challenge.segments, isEmpty);
    expect(challenge.recurrenceType, 'none');
  });
}
