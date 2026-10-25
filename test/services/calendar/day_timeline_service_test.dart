import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/calendar/day_timeline_service.dart';

void main() {
  test('parses meal and strength timeline details', () {
    final data = DayTimelineData.fromJson({
      'entry_date': '2026-10-20',
      'daily_summary': {'steps': 9000, 'sleep_minutes_asleep': 450},
      'planned_activity': {
        'schedule_type': 'training',
        'training_day_label': 'Push day',
      },
      'events': [
        {
          'id': 'meal-1',
          'type': 'meal',
          'title': 'Breakfast',
          'occurred_at': '2026-10-20T08:30:00+00:00',
          'details': {
            'totals': {'calories': 450, 'protein_g': 30},
            'items': [
              {'name': 'Eggs', 'calories': 210},
            ],
          },
        },
        {
          'id': 'strength-1',
          'type': 'strength',
          'title': 'Push day',
          'occurred_at': '2026-10-20T15:30:00+00:00',
          'details': {
            'exercises': [
              {
                'name': 'Bench press',
                'sets': [
                  {'set_index': 1, 'reps': 10, 'weight_kg': 60},
                ],
              },
            ],
          },
        },
        {
          'id': 'planned-meal-91',
          'type': 'planned_meal',
          'title': 'Dinner',
          'occurred_at': '2026-10-20T19:30:00+00:00',
          'details': {
            'plan_id': 91,
            'status': 'planned',
            'can_mark_eaten': false,
            'totals': {'calories': 620, 'protein_g': 48},
            'items': [
              {'name': 'Chicken bowl', 'calories': 620},
            ],
          },
        },
      ],
    });

    expect(data.events, hasLength(3));
    expect(data.events.first.title, 'Breakfast');
    expect(data.events.first.details['totals']['calories'], 450);
    expect(data.events[1].details['exercises'][0]['sets'][0]['reps'], 10);
    expect(data.events.last.type, 'planned_meal');
    expect(data.events.last.details['plan_id'], 91);
    expect(data.dailySummary?['steps'], 9000);
    expect(data.plannedActivity?['training_day_label'], 'Push day');
  });
}
