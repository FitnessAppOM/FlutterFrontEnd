import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/training/previous_exercise_weight.dart';

void main() {
  test('ignores a planned weight on an exercise never completed', () {
    expect(
      previousCompletedExerciseWeight({
        'program_compliance': {'completed': null, 'weight_used': 40},
      }),
      isNull,
    );
  });

  test(
    'does not show exercise A weight as previous for untrained exercise B',
    () {
      final exerciseA = {
        'program_compliance': {
          'completed': true,
          'logged_at': '2026-09-20T12:00:00',
          'weight_used': 40,
        },
      };
      final exerciseB = {
        'program_compliance': {'completed': null, 'weight_used': 40},
      };

      expect(previousCompletedExerciseWeight(exerciseA), 40);
      expect(previousCompletedExerciseWeight(exerciseB), isNull);
    },
  );

  test('ignores a top-level weight with no verified completion', () {
    expect(previousCompletedExerciseWeight({'weight_used': 40}), isNull);
  });

  test(
    'ignores incomplete records and completed records without a log time',
    () {
      expect(
        previousCompletedExerciseWeight({
          'program_compliance': {
            'completed': false,
            'logged_at': '2026-09-20T12:00:00',
            'weight_used': 40,
          },
        }),
        isNull,
      );
      expect(
        previousCompletedExerciseWeight({
          'program_compliance': {'completed': true, 'weight_used': 40},
        }),
        isNull,
      );
    },
  );

  test('shows a completed exercise weight from an earlier session', () {
    expect(
      previousCompletedExerciseWeight({
        'program_compliance': {
          'completed': true,
          'logged_at': '2026-09-20T12:00:00',
          'weight_used': 40,
        },
      }),
      40,
    );
  });

  test(
    'a completed exercise without a weight still has no previous weight',
    () {
      expect(
        previousCompletedExerciseWeight({
          'program_compliance': {
            'completed': true,
            'logged_at': '2026-09-20T12:00:00',
            'weight_used': null,
          },
        }),
        isNull,
      );
    },
  );

  test('accepts cached JSON compliance but not malformed data', () {
    expect(
      previousCompletedExerciseWeight({
        'program_compliance':
            '{"completed":true,"logged_at":"2026-09-20","weight_used":35}',
      }),
      35,
    );
    expect(
      previousCompletedExerciseWeight({'program_compliance': '{invalid'}),
      isNull,
    );
  });
}
