import 'dart:async';

import 'package:flutter/material.dart';
import 'calendar_action_style.dart';
import 'package:intl/intl.dart';

import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/timeline_nutrition_summary.dart';
import '../../services/diet/diet_service.dart';

/// Loads independently so an unavailable nutrition summary never hides events.
class TimelineNutritionHeader extends StatefulWidget {
  const TimelineNutritionHeader({
    super.key,
    required this.date,
    this.refreshRevision = 0,
  });

  final DateTime date;
  final int refreshRevision;

  @override
  State<TimelineNutritionHeader> createState() =>
      _TimelineNutritionHeaderState();
}

class _TimelineNutritionHeaderState extends State<TimelineNutritionHeader> {
  TimelineNutritionSummary? _summary;
  bool _loading = true;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant TimelineNutritionHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.date, widget.date) ||
        oldWidget.refreshRevision != widget.refreshRevision) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final date = widget.date;
    setState(() {
      _loading = true;
      _failed = false;
      _summary = null;
    });
    try {
      final userId = await AccountStorage.getUserId();
      if (!mounted || request != _request) return;
      if (userId == null || userId <= 0) throw StateError('No active user');
      final response = await DietService.fetchDaySummary(
        userId,
        date: date,
      ).timeout(const Duration(seconds: 15));
      final summary = TimelineNutritionSummary.fromResponse(response);
      final activeUserId = await AccountStorage.getUserId();
      if (!mounted || request != _request) return;
      if (activeUserId != userId) throw StateError('Account changed');
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final summary = _summary;
    return Container(
      key: const ValueKey('timeline-nutrition'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate('timeline_nutrition_title'),
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            Semantics(
              label: t.translate('common_loading'),
              child: const LinearProgressIndicator(),
            )
          else if (_failed) ...[
            Text(
              t.translate('timeline_nutrition_error'),
              style: TextStyle(color: colors.textSecondary),
            ),
            TextButton(
              style: calendarActionStyle(context),
              onPressed: _load,
              child: Text(t.translate('generating_retry')),
            ),
          ] else if (summary != null) ...[
            if (summary.target == null) ...[
              Text(
                t.translate('diet_no_targets_yet'),
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                // Wrap at large text sizes instead of clipping four tiny rings.
                final columns =
                    constraints.maxWidth >= 540 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 20
                    ? 4
                    : 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final metric in TimelineNutritionSummary.metrics)
                      SizedBox(
                        width:
                            (constraints.maxWidth - 12 * (columns - 1)) /
                            columns,
                        child: _MetricProgress(
                          metric: metric,
                          summary: summary,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricProgress extends StatelessWidget {
  const _MetricProgress({required this.metric, required this.summary});

  final String metric;
  final TimelineNutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final format = NumberFormat.decimalPattern(t.locale.languageCode);
    final consumed = summary.consumed[metric]!;
    final target = summary.target?[metric];
    final remaining = summary.remaining?[metric];
    final metricName = switch (metric) {
      'protein_g' => 'protein',
      'carbs_g' => 'carbs',
      'fat_g' => 'fat',
      _ => 'calories',
    };
    final unit = t.translate(
      metric == 'calories' ? 'diet_kcal_unit' : 'timeline_nutrition_grams',
    );
    final progress = target != null && target > 0
        ? (consumed / target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return Column(
      key: ValueKey('timeline-nutrition-$metric'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate('diet_target_metric_$metricName'),
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${t.translate('diet_consumed')}: ${format.format(consumed)} $unit',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        if (target != null) ...[
          Text(
            '${t.translate('timeline_nutrition_target')}: ${format.format(target)} $unit',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            color: colors.accent,
            backgroundColor: colors.border,
            semanticsLabel: t.translate('diet_target_metric_$metricName'),
          ),
        ],
        if (remaining != null) ...[
          const SizedBox(height: 6),
          Text(
            remaining < 0
                ? t
                      .translate('timeline_nutrition_over')
                      .replaceAll('{amount}', format.format(remaining.abs()))
                      .replaceAll('{unit}', unit)
                : '${t.translate('diet_remaining')}: ${format.format(remaining)} $unit',
            style: TextStyle(color: colors.textPrimary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
