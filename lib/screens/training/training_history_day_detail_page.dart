import 'package:flutter/material.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_back_button.dart';
import '../../TaqaUI/components/taqa_mini_tag.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../localization/app_localizations.dart';

class TrainingHistoryDayDetailPage extends StatelessWidget {
  const TrainingHistoryDayDetailPage({
    super.key,
    required this.dayLabel,
    this.weekLabel,
    required this.completedExercises,
  });

  final String dayLabel;
  final String? weekLabel;
  final List<Map<String, dynamic>> completedExercises;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
          Text(
            weekLabel == null || weekLabel!.isEmpty
                ? t.translate('training_completed_exercises')
                : "${t.translate('training_completed_exercises')} • $weekLabel",
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          if (completedExercises.isEmpty)
            Text(
              t.translate('training_no_completed_exercises'),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
              ),
            )
          else
            ...completedExercises.map((exercise) {
              return Padding(
                padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                child: TaqaTrainingHistoryExerciseCard(
                  exercise: exercise,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TrainingHistoryExerciseSetPage(exercise: exercise),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class TaqaTrainingHistoryExerciseCard extends StatelessWidget {
  const TaqaTrainingHistoryExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  final Map<String, dynamic> exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final title = (exercise['exercise_name'] ?? '').toString();

    return Material(
      color: TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(15),
        child: Container(
          padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: TaqaUiScale.radius(15),
            border: Border.all(
              color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
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
              Icon(
                isRtl
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: TaqaUiScale.sp(16),
                color: TaqaUiColors.charcoal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrainingHistoryExerciseSetPage extends StatelessWidget {
  const TrainingHistoryExerciseSetPage({super.key, required this.exercise});

  final Map<String, dynamic> exercise;

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final seconds = safe % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$mm:$ss'
        : '$mm:$ss';
  }

  String _formatWeight(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  List<Map<String, dynamic>> _setRows() {
    final rawRows = exercise['set_rows'];
    if (rawRows is! List) return const [];
    final rows = rawRows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    rows.sort(
      (a, b) => (_intValue(a['set_index']) ?? 0).compareTo(
        _intValue(b['set_index']) ?? 0,
      ),
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final title = (exercise['exercise_name'] ?? '').toString();
    final rows = _setRows();

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: title,
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        titleColor: TaqaUiColors.charcoal,
        leading: const TaqaBackButton(color: TaqaUiColors.charcoal),
      ),
      body: ListView(
        padding: TaqaUiScale.insetsLTRB(16, 12, 16, 24),
        children: [
          Text(
            t.translate('training_set_details'),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(25),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.charcoal,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          if (rows.isEmpty)
            Text(
              t.translate('training_no_set_details'),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
              ),
            )
          else
            ...rows.map(
              (row) => Padding(
                padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                child: _TrainingHistorySetCard(
                  setIndex: _intValue(row['set_index']) ?? 0,
                  reps: _intValue(row['reps']),
                  rir: _intValue(row['rir']),
                  weightKg: _doubleValue(row['weight_kg']),
                  durationSeconds: _intValue(row['performed_time_seconds']),
                  restSeconds: _intValue(row['rest_after_seconds']),
                  formatDuration: _formatDuration,
                  formatWeight: _formatWeight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainingHistorySetCard extends StatelessWidget {
  const _TrainingHistorySetCard({
    required this.setIndex,
    required this.reps,
    required this.rir,
    required this.weightKg,
    required this.durationSeconds,
    required this.restSeconds,
    required this.formatDuration,
    required this.formatWeight,
  });

  final int setIndex;
  final int? reps;
  final int? rir;
  final double? weightKg;
  final int? durationSeconds;
  final int? restSeconds;
  final String Function(int seconds) formatDuration;
  final String Function(double weight) formatWeight;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final details = <String>[
      if (reps != null) '$reps ${t.translate('training_reps')}',
      if (weightKg != null)
        '${formatWeight(weightKg!)} ${t.translate('training_kg')}',
      if (rir != null) '${t.translate('training_rir_label')} $rir',
      if (durationSeconds != null)
        '${t.translate('training_time')} ${formatDuration(durationSeconds!)}',
      if (restSeconds != null)
        '${t.translate('training_rest')} ${formatDuration(restSeconds!)}',
    ];

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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TaqaUiColors.lime,
              borderRadius: TaqaUiScale.radius(10),
            ),
            child: Text(
              '$setIndex',
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.charcoal,
              ),
            ),
          ),
          SizedBox(width: TaqaUiScale.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.translate('training_set')} $setIndex',
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w700,
                    color: TaqaUiColors.charcoal,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  SizedBox(height: TaqaUiScale.h(8)),
                  Wrap(
                    spacing: TaqaUiScale.w(8),
                    runSpacing: TaqaUiScale.h(6),
                    children: details
                        .map((detail) => TaqaMiniTag(label: detail))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          TaqaMiniTag(label: t.translate('training_done').toUpperCase()),
        ],
      ),
    );
  }
}
