/// Live nutrition from the Diet day-summary API. Captured snapshots and planned
/// meals are deliberately not combined with these values.
class TimelineNutritionSummary {
  const TimelineNutritionSummary({
    required this.consumed,
    required this.target,
    required this.remaining,
  });

  static const metrics = ['calories', 'protein_g', 'carbs_g', 'fat_g'];

  final Map<String, num> consumed;
  final Map<String, num>? target;
  final Map<String, num>? remaining;

  factory TimelineNutritionSummary.fromResponse(Map<String, dynamic> response) {
    final live = response['live'];
    if (live is! Map) {
      throw const FormatException('Missing live nutrition summary');
    }
    Map<String, num> values(Object? raw) {
      if (raw is! Map) {
        throw const FormatException('Missing nutrition values');
      }
      return Map.unmodifiable({
        for (final metric in metrics) metric: _number(raw[metric]),
      });
    }

    final target = live['target'];
    return TimelineNutritionSummary(
      consumed: values(live['consumed']),
      target: target == null ? null : values(target),
      remaining: target == null ? null : values(live['remaining']),
    );
  }

  static num _number(Object? raw) {
    if (raw is! num || !raw.isFinite) {
      throw const FormatException('Invalid nutrition value');
    }
    return raw;
  }
}
