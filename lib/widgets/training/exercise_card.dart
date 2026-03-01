import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/training/training_service.dart';


class ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onTap;
  final VoidCallback onReplace;
  final bool disabled;


  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    required this.onReplace,
    this.disabled = false,
  });

  Map<String, dynamic>? _extractCompliance(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _valueAsText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      if (value == 0) return null;
      final asInt = value.toInt();
      return (value == asInt) ? asInt.toString() : value.toString();
    }
    if (value is bool) return value ? "1" : null;
    return value.toString();
  }


  @override
  Widget build(BuildContext context) {
    String _lower(dynamic v) => (v ?? '').toString().trim().toLowerCase();
    final category = _lower(exercise['category']);
    final exType = _lower(exercise['exercise_type']);
    final animName = _lower(exercise['animation_name']);
    final name = _lower(exercise['exercise_name']);
    final isCardio = [
      category,
      exType,
      animName,
      name,
    ].any((v) => v.contains('cardio')) ||
        animName.startsWith('cardio -');

    DateTime? _parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      if (value is num) {
        final intVal = value.toInt();
        // Accept both seconds and milliseconds since epoch.
        if (intVal > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(intVal);
        }
        if (intVal > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
        }
      }
      return null;
    }

    DateTime _startOfCurrentWeekSunday() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // In Dart, Sunday == 7. We want the most recent Sunday 00:00.
      final daysSinceSunday = now.weekday % 7;
      return today.subtract(Duration(days: daysSinceSunday));
    }

    final DateTime _weekStart = _startOfCurrentWeekSunday();
    final Map<String, dynamic>? compliance =
        _extractCompliance(exercise['program_compliance']) ??
            _extractCompliance(exercise['compliance']);
    final String? overrideSets =
        _valueAsText(compliance?['performed_sets'] ?? exercise['performed_sets']);
    final String? overrideReps =
        _valueAsText(compliance?['performed_reps'] ?? exercise['performed_reps']);
    final String setsLabel = overrideSets ?? exercise['sets'].toString();
    final String repsLabel = overrideReps ?? exercise['reps'].toString();
    final String? overrideRir =
        _valueAsText(compliance?['performed_rir'] ?? exercise['performed_rir']);
    final String rirLabel = overrideRir ?? exercise['rir'].toString();

    bool _isInCurrentWeek(dynamic loggedAt) {
      final dt = _parseDate(loggedAt);
      if (dt == null) return false;
      return !dt.isBefore(_weekStart);
    }

    bool _isCompleted(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final s = value.toString().trim().toLowerCase();
      if (s.isEmpty) return false;
      // Accept common truthy markers, including "1", "t", and numeric strings.
      if (s == "true" || s == "yes" || s == "y" || s == "t" || s == "1") {
        return true;
      }
      final numeric = num.tryParse(s);
      if (numeric != null) return numeric != 0;
      // Fallback: any non-falsey string is treated as completed (e.g. logged_at timestamp).
      return !(s == "false" || s == "f" || s == "no" || s == "n" || s == "0");
    }

    bool _hasComplianceCompleted(dynamic compliance) {
      if (compliance == null) return false;
      if (compliance is String) {
        try {
          final decoded = jsonDecode(compliance);
          return _hasComplianceCompleted(decoded);
        } catch (_) {
          return _isCompleted(compliance);
        }
      }
      if (compliance is Map) {
        if (!_isInCurrentWeek(compliance['logged_at'])) return false;
        // Check common fields returned from program_compliance payloads. Ignore logged_at alone;
        // we only consider explicit completion flags or logged performance metrics.
        final possibleFlags = [
          compliance['completed'],
          compliance['is_completed'],
          compliance['performed_sets'],
          compliance['performed_reps'],
          compliance['performed_time_seconds'],
          // Consider textual statuses that imply completion.
          if (compliance['status'] != null)
            (compliance['status'].toString().toLowerCase().contains("complete") ||
                    compliance['status'].toString().toLowerCase().contains("done") ||
                    compliance['status'].toString().toLowerCase().contains("finish")),
        ];
        return possibleFlags.any(_isCompleted);
      }
      if (compliance is Iterable) {
        return compliance.any((item) => _hasComplianceCompleted(item));
      }
      return _isCompleted(compliance);
    }

    // Accept multiple backend representations for completion/compliance flags.
    final completionFields = [
      exercise['is_completed'],
      exercise['completed'],
      exercise['program_compliance_completed'],
      exercise['compliance_status'],
      exercise['performed_sets'],
      exercise['performed_reps'],
      exercise['performed_time_seconds'],
      exercise['weight_used'],
    ];

    final bool completed =
        completionFields.any(_isCompleted) ||
        _hasComplianceCompleted(exercise['program_compliance']) ||
        _hasComplianceCompleted(exercise['compliance']);
    final cs = Theme.of(context).colorScheme;

    final gradientColors = completed
        ? const [Color(0xFF0E2A1E), Color(0xFF0B1F1A)]
        : const [Color(0xFF0F162A), Color(0xFF0A0F1C)];
    final shadowColor =
        completed ? Colors.greenAccent.withOpacity(0.35) : Colors.black.withOpacity(0.45);
    final borderColor =
        completed ? Colors.greenAccent.withOpacity(0.6) : Colors.white.withOpacity(0.07);
    final statusChip = completed
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.greenAccent,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 14, color: Colors.greenAccent),
                SizedBox(width: 3),
                Text(
                  "Done",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.greenAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        : null;
    final replaceChip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onReplace,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(disabled ? 0.03 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24.withOpacity(disabled ? 0.5 : 1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
            SizedBox(width: 4),
            Text(
              "Replace",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );


    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: AbsorbPointer(
        absorbing: disabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: disabled ? null : onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: completed ? 18 : 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 74,
                        height: 66,
                        color: Colors.black26,
                        child: ((((exercise['animation_url'] ?? '').toString().trim()).isEmpty) &&
                                (((exercise['animation_rel_path'] ?? '').toString().trim()).isEmpty))
                            ? const SizedBox.shrink()
                              : Image.network(
                                TrainingService.animationImageUrl(
                                  exercise['animation_url']?.toString(),
                                  exercise['animation_rel_path']?.toString(),
                                ),
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox.shrink();
                                },
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  exercise['exercise_name'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: completed ? Colors.greenAccent : Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (statusChip != null) statusChip,
                              const SizedBox(width: 6),
                              if (!completed && !isCardio) replaceChip,
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (!isCardio)
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _StatChip(
                                  icon: Icons.repeat,
                                  label: "$setsLabel x $repsLabel",
                                ),
                                _StatChip(
                                  icon: Icons.bolt,
                                  label: "RIR $rirLabel",
                                ),
                              ],
                            ),
                          if ((exercise['primary_muscles'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.fiber_manual_record,
                                    size: 10, color: cs.secondary.withOpacity(0.85)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    exercise['primary_muscles'],
                                    style: TextStyle(
                                      color: cs.secondary.withOpacity(0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _StatChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (accent ?? Colors.white).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (accent ?? Colors.white).withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent ?? Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
