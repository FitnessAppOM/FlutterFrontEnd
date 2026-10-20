import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/training/training_schedule_service.dart';

void main() {
  group('TrainingScheduleEntry', () {
    test('parses an isolated training plan', () {
      final entry = TrainingScheduleEntry.fromJson({
        'scheduled_date': '2026-10-22',
        'schedule_type': 'training',
        'program_id': 12,
        'training_day_index': 2,
        'training_day_label': 'Push Day',
        'created_at': '2026-10-20T12:30:00',
        'updated_at': '2026-10-20T12:30:00',
      });

      expect(entry.scheduledDate, DateTime(2026, 10, 22));
      expect(entry.programId, 12);
      expect(entry.trainingDayIndex, 2);
      expect(entry.trainingDayLabel, 'Push Day');
      expect(entry.isTraining, isTrue);
      expect(entry.isRest, isFalse);
    });

    test('parses a rest plan without program data', () {
      final entry = TrainingScheduleEntry.fromJson({
        'scheduled_date': '2026-10-23',
        'schedule_type': 'rest',
        'program_id': null,
        'training_day_index': null,
        'training_day_label': null,
      });

      expect(entry.programId, isNull);
      expect(entry.trainingDayIndex, isNull);
      expect(entry.isRest, isTrue);
    });
  });
}
