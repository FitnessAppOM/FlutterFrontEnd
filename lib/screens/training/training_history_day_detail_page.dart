import 'dart:convert';

import 'package:flutter/material.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_back_button.dart';
import '../../TaqaUI/components/taqa_mini_tag.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';

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
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: dayLabel,
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        titleColor: TaqaUiColors.charcoal,
        leading: const TaqaBackButton(color: TaqaUiColors.charcoal),
      ),
      body: ListView(
        padding: TaqaUiScale.insetsLTRB(16, 12, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  weekLabel == null || weekLabel!.isEmpty
                      ? "Completed exercises"
                      : "Completed exercises • $weekLabel",
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w400,
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                  ),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(8)),
              TaqaMiniTag(label: statusText.toUpperCase()),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          if (completedExercises.isEmpty)
            Text(
              "No completed exercises.",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
              ),
            )
          else
            ...completedExercises.map((ex) {
              return Padding(
                padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                child: TaqaTrainingHistoryExerciseCard(exercise: ex),
              );
            }),
        ],
      ),
    );
  }
}

/// Shared completed-exercise card for training history views.
class TaqaTrainingHistoryExerciseCard extends StatelessWidget {
  const TaqaTrainingHistoryExerciseCard({super.key, required this.exercise});

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
    String lower(dynamic v) => (v ?? '').toString().trim().toLowerCase();
    final category = lower(exercise['category']);
    final exType = lower(exercise['exercise_type']);
    final animName = lower(exercise['animation_name']);
    final name = lower(exercise['exercise_name']);
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
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: TaqaUiScale.w(36),
            height: TaqaUiScale.w(36),
            decoration: BoxDecoration(
              color: TaqaUiColors.lime,
              borderRadius: TaqaUiScale.radius(10),
            ),
            child: Icon(
              Icons.check,
              size: TaqaUiScale.sp(18),
              color: TaqaUiColors.charcoal,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(12)),
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
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(15),
                          fontWeight: FontWeight.w700,
                          color: TaqaUiColors.charcoal,
                        ),
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(8)),
                    const TaqaMiniTag(label: "DONE"),
                  ],
                ),
                if (!isCardio) ...[
                  SizedBox(height: TaqaUiScale.h(8)),
                  Wrap(
                    spacing: TaqaUiScale.w(8),
                    runSpacing: TaqaUiScale.h(6),
                    children: [
                      TaqaMiniTag(label: "$setsLabel x $repsLabel"),
                      TaqaMiniTag(label: "RIR $rirLabel"),
                    ],
                  ),
                ],
                if (muscles.isNotEmpty) ...[
                  SizedBox(height: TaqaUiScale.h(8)),
                  Text(
                    muscles,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w600,
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
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
