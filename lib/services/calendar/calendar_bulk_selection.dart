import 'calendar_food_commands.dart';
import 'calendar_time_zone.dart';

/// One entry per parent: null means whole meal; a set means selected children.
class CalendarBulkSelection {
  final Map<String, Set<String>?> choices = {};
  static String key(CalendarFoodState s) => '${s.kind}:${s.id}';
  static String itemKey(CalendarFoodState s, Map<String, dynamic> item) =>
      '${item[s.kind == 'meal' ? 'id' : 'item_key']}';

  bool whole(CalendarFoodState s) =>
      choices.containsKey(key(s)) && choices[key(s)] == null;
  bool contains(CalendarFoodState s) => choices.containsKey(key(s));
  bool itemSelected(CalendarFoodState s, String id) =>
      whole(s) || (choices[key(s)]?.contains(id) ?? false);
  int get count => choices.values.fold(0, (n, ids) => n + (ids?.length ?? 1));
  bool get hasItems => choices.values.any((ids) => ids != null);

  void selectWhole(CalendarFoodState s, bool selected) {
    if (selected) {
      choices[key(s)] = null;
    } else {
      choices.remove(key(s));
    }
  }

  void selectItem(CalendarFoodState s, String id, bool selected) {
    final ids = whole(s)
        ? s.items.map((i) => itemKey(s, i)).toSet()
        : Set<String>.from(choices[key(s)] ?? {});
    if (selected) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    if (ids.isEmpty) {
      choices.remove(key(s));
    } else {
      choices[key(s)] = ids;
    }
  }

  void retain(List<CalendarFoodState> states) {
    choices.removeWhere(
      (key, _) => !states.any((s) => CalendarBulkSelection.key(s) == key),
    );
    for (final s in states) {
      final ids = choices[key(s)];
      if (ids != null) {
        ids.retainAll(s.items.map((i) => itemKey(s, i)));
        if (ids.isEmpty) choices.remove(key(s));
      }
    }
  }

  List<Map<String, dynamic>> entries({
    required List<CalendarFoodState> states,
    required String action,
    required String zone,
    required List<DateTime> anchors,
    required DateTime previewNow,
  }) {
    final selected = states.where(contains).toList();
    if (count == 0 ||
        count > 50 ||
        (action != 'delete' && selected.length * anchors.length > 100)) {
      throw const CalendarCommandError('calendar_bulk_bounds');
    }
    if (action == 'reschedule' &&
        (hasItems || selected.any((s) => s.scheduledAt == null))) {
      throw const CalendarCommandError('calendar_bulk_whole_time');
    }
    if (action == 'delete' &&
        selected.any(
          (s) => !whole(s) && (s.overrides?.any((v) => v != null) ?? false),
        )) {
      throw const CalendarCommandError('calendar_bulk_override_delete');
    }
    final timed =
        selected.map((s) => s.scheduledAt).whereType<DateTime>().toList()
          ..sort();
    final first = timed.isEmpty ? null : timed.first;
    return selected.map((s) {
      final ids = choices[key(s)];
      final shift = s.scheduledAt == null || first == null
          ? Duration.zero
          : s.scheduledAt!.difference(first);
      return <String, dynamic>{
        'source': s.source,
        if (ids != null && s.kind == 'meal')
          'item_ids': ids.map(int.parse).toList(),
        if (ids != null && s.kind == 'meal_plan') 'item_keys': ids.toList(),
        'destinations': action == 'delete'
            ? <Map<String, dynamic>>[]
            : anchors.map((anchor) {
                final at = CalendarTimeZone.inZone(
                  anchor.toUtc().add(shift),
                  zone,
                );
                if (action == 'reschedule' &&
                    s.kind == 'meal' &&
                    at.isAfter(previewNow)) {
                  throw const CalendarCommandError('calendar_time_future');
                }
                return <String, dynamic>{
                  'scheduled_date': calendarDate(at),
                  'scheduled_at': CalendarTimeZone.timestamp(at, precise: true),
                  'expected_status': action == 'copy'
                      ? (at.isAfter(previewNow) ? 'planned' : 'logged')
                      : (s.kind == 'meal' ? 'logged' : 'planned'),
                };
              }).toList(),
      };
    }).toList();
  }
}
