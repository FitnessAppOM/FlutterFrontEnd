import 'package:flutter/material.dart';
import 'package:taqaproject/TaqaUI/components/taqa_back_button.dart';
import 'package:taqaproject/TaqaUI/components/taqa_page_app_bar.dart';

import 'dart:convert';

class TrainingHistoryDayDetailPage extends StatelessWidget {
  const TrainingHistoryDayDetailPage({
    super.key,
    required this.dayLabel,
    required this.statusText,
    this.weekLabel,
    required this.completedExercises,
  });

  final String dayLabel;
  final String statusText;
  final String? weekLabel;
  final List<Map<String, dynamic>> completedExercises;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: TaqaPageAppBar(
        title: dayLabel,
        backgroundColor: const Color(0xFF0F1014),
        leading: const TaqaBackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  weekLabel == null || weekLabel!.isEmpty
                      ? "Completed exercises"
                      : "Completed exercises • $weekLabel",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (completedExercises.isEmpty)
            Text(
              "No completed exercises.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            )
          else
            ...completedExercises.map((ex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryExerciseCard(exercise: ex),
              );
            }),
        ],
      ),
    );
  }
}

class _HistoryExerciseCard extends StatelessWidget {
  const _HistoryExerciseCard({required this.exercise});

  final Map<String, dynamic> exercise;

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
    final isCardio =
        [category, exType, animName, name].any((v) => v.contains('cardio')) ||
        animName.startsWith('cardio -');

    final compliance =
        _extractCompliance(exercise['program_compliance']) ??
        _extractCompliance(exercise['compliance']);

    final performedSets = _valueAsText(
      compliance?['performed_sets'] ?? exercise['performed_sets'],
    );
    final performedReps = _valueAsText(
      compliance?['performed_reps'] ?? exercise['performed_reps'],
    );
    final performedRir = _valueAsText(
      compliance?['performed_rir'] ?? exercise['performed_rir'],
    );

    final setsLabel = performedSets ?? _valueAsText(exercise['sets']) ?? '-';
    final repsLabel = performedReps ?? _valueAsText(exercise['reps']) ?? '-';
    final rirLabel = performedRir ?? _valueAsText(exercise['rir']) ?? '-';

    final title = exercise['exercise_name']?.toString() ?? '';
    final muscles = (exercise['primary_muscles'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F162A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.6)),
            ),
            child: const Icon(Icons.check, size: 18, color: Colors.greenAccent),
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
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent),
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isCardio) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HistoryStatChip(
                        icon: Icons.repeat,
                        label: "$setsLabel x $repsLabel",
                      ),
                      _HistoryStatChip(
                        icon: Icons.bolt,
                        label: "RIR $rirLabel",
                      ),
                    ],
                  ),
                ],
                if (muscles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    muscles,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatChip extends StatelessWidget {
  const _HistoryStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
