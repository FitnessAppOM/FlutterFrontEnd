import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_back_button.dart';
import '../TaqaUI/components/taqa_date_carousel_switcher.dart';
import '../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../TaqaUI/components/taqa_empty_state_row.dart';
import '../TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import '../TaqaUI/components/taqa_expert_dashboard_ui.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_pill_tab.dart';
import '../TaqaUI/components/taqa_profile_info_section.dart';
import '../TaqaUI/components/taqa_value_box.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/ranged_bar_chart.dart';
import '../widgets/charts/simple_line_chart.dart';
import 'expert_training_plan_review_page.dart';
import '../core/user_friendly_error.dart';

enum ExpertWeeklyMetricsDetailType { waterSteps, trainingCardio, wearables }

class ExpertWeeklyMetricsDetailPage extends StatefulWidget {
  const ExpertWeeklyMetricsDetailPage({
    super.key,
    required this.type,
    required this.clientUserId,
    required this.clientName,
    required this.analyticsData,
    this.clientAvatarUrl,
    this.clientActivityStatus,
    this.activeProgram = const {},
    this.trainingPlanError,
    this.onTrainingPlanVerified,
  });

  final ExpertWeeklyMetricsDetailType type;
  final int clientUserId;
  final String clientName;
  final String? clientAvatarUrl;
  final String? clientActivityStatus;
  final Map<String, dynamic> analyticsData;
  final Map<String, dynamic> activeProgram;
  final String? trainingPlanError;
  final VoidCallback? onTrainingPlanVerified;

  @override
  State<ExpertWeeklyMetricsDetailPage> createState() =>
      _ExpertWeeklyMetricsDetailPageState();
}

class _ExpertWeeklyMetricsDetailPageState
    extends State<ExpertWeeklyMetricsDetailPage> {
  static const String _wearableWhoop = 'whoop';
  static const String _wearableFitbit = 'fitbit';
  int? _selectedPrimaryBar;
  int? _selectedTrainingDayVolumeBar;
  int? _selectedExerciseVolumeBar;
  int? _selectedAdherenceBar;
  int _weekOffset = 0;
  bool _loadingWeek = false;
  String? _weekError;
  bool _loadingExerciseHistory = false;
  String? _exerciseHistoryError;
  List<Map<String, dynamic>> _exerciseHistoryEntries = const [];
  String _selectedWearableProvider = _wearableWhoop;
  late Map<String, dynamic> _analyticsData;
  late Map<String, dynamic> _activeProgram;
  String? _trainingPlanError;
  final Map<int, Map<String, dynamic>> _weeklyCache =
      <int, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _analyticsData = Map<String, dynamic>.from(widget.analyticsData);
    _activeProgram = Map<String, dynamic>.from(widget.activeProgram);
    _trainingPlanError = widget.trainingPlanError;
    _weeklyCache[0] = Map<String, dynamic>.from(widget.analyticsData);
    if (widget.type == ExpertWeeklyMetricsDetailType.trainingCardio) {
      unawaited(_loadExerciseHistory());
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    final parsed = switch (value) {
      double v => v,
      num v => v.toDouble(),
      _ => double.tryParse(value?.toString() ?? '') ?? fallback,
    };
    return parsed.isFinite ? parsed : fallback;
  }

  DateTime? _dateOnly(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _weekDates({
    required String? startRaw,
    required String? endRaw,
  }) {
    final end =
        _dateOnly(endRaw) ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final start = _dateOnly(startRaw) ?? end.subtract(const Duration(days: 6));
    final normalizedStart = DateTime(start.year, start.month, start.day);
    return List<DateTime>.generate(
      7,
      (i) => normalizedStart.add(Duration(days: i)),
    );
  }

  String _weekday(DateTime date) => DateFormat('EEE').format(date);

  String _dayDetail(DateTime date) => DateFormat('dd MMM').format(date);

  String _weekRangeLabel() {
    final source = _map(_analyticsData['daily_metrics']);
    final start = _dateOnly(source['last_7_start']?.toString());
    final end = _dateOnly(source['today']?.toString());
    if (start == null || end == null) {
      if (_weekOffset == 0) return 'Current 7 days';
      return '${_weekOffset}w ago';
    }
    return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}';
  }

  Future<void> _changeWeek(int nextOffset) async {
    if (nextOffset < 0 || _loadingWeek) return;

    final cached = _weeklyCache[nextOffset];
    if (cached != null) {
      setState(() {
        _weekOffset = nextOffset;
        _analyticsData = Map<String, dynamic>.from(cached);
        _weekError = null;
        _selectedPrimaryBar = null;
        _selectedTrainingDayVolumeBar = null;
        _selectedExerciseVolumeBar = null;
        _selectedAdherenceBar = null;
      });
      return;
    }

    setState(() {
      _loadingWeek = true;
      _weekError = null;
    });
    try {
      final data = await ProgressionReviewService.fetchClientAnalytics(
        widget.clientUserId,
        weekOffset: nextOffset,
      );
      if (!mounted) return;
      setState(() {
        _weekOffset = nextOffset;
        _analyticsData = Map<String, dynamic>.from(data);
        _weeklyCache[nextOffset] = Map<String, dynamic>.from(data);
        _selectedPrimaryBar = null;
        _selectedTrainingDayVolumeBar = null;
        _selectedExerciseVolumeBar = null;
        _selectedAdherenceBar = null;
        _loadingWeek = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weekError = userFriendlyErrorMessage(e);
        _loadingWeek = false;
      });
    }
  }

  Future<void> _loadExerciseHistory() async {
    if (mounted) {
      setState(() {
        _loadingExerciseHistory = true;
        _exerciseHistoryError = null;
      });
    }
    try {
      final entries = await ProgressionReviewService.fetchClientTrainingHistory(
        clientUserId: widget.clientUserId,
        limitDays: 540,
      );
      if (!mounted) return;
      setState(() {
        _exerciseHistoryEntries = entries;
        _loadingExerciseHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exerciseHistoryError = userFriendlyErrorMessage(e);
        _loadingExerciseHistory = false;
      });
    }
  }

  DateTime _weekEndDateForOffset(int offset) {
    final source = _map(_analyticsData['daily_metrics']);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    // Analytics for a historical selection contains that selection's week-end
    // date. Convert it back to the current-week anchor before positioning the
    // carousel labels; otherwise the selected offset is applied twice and the
    // tapped edge label never reaches the centre.
    final selectedWeekEnd =
        _dateOnly(source['today']?.toString()) ??
        today.subtract(Duration(days: _weekOffset * 7));
    final currentWeekEnd = selectedWeekEnd.add(Duration(days: _weekOffset * 7));
    return currentWeekEnd.subtract(Duration(days: offset * 7));
  }

  bool get _usesLightMetricDetail =>
      widget.type == ExpertWeeklyMetricsDetailType.trainingCardio ||
      widget.type == ExpertWeeklyMetricsDetailType.waterSteps ||
      widget.type == ExpertWeeklyMetricsDetailType.wearables;

  Widget _buildWeekSwitcher() {
    final canGoNewer = _weekOffset > 0;
    final previousDate = _weekEndDateForOffset(_weekOffset + 1);
    final selectedDate = _weekEndDateForOffset(_weekOffset);
    final nextDate = _weekEndDateForOffset(_weekOffset - 1);
    return TaqaDateCarouselSwitcher(
      previousDate: previousDate,
      selectedDate: selectedDate,
      nextDate: nextDate,
      onPrevious: () => _changeWeek(_weekOffset + 1),
      onSelected: _weekOffset == 0 ? null : () => _changeWeek(0),
      onNext: canGoNewer ? () => _changeWeek(_weekOffset - 1) : null,
      loading: _loadingWeek,
      textColor: TaqaUiColors.charcoal,
    );
  }

  String _formatCompact(double value, {int decimals = 0}) {
    final abs = value.abs();
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(decimals);
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
    Color? accent,
  }) {
    if (_usesLightMetricDetail) {
      return TaqaValueBox(label: label, value: value);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (accent ?? Colors.white).withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    if (_usesLightMetricDetail) {
      return TaqaClientDashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaqaClientDashboardTitleText(title),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              SizedBox(height: TaqaUiScale.h(4)),
              TaqaClientDashboardBodyText(
                subtitle,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
              ),
            ],
            SizedBox(height: TaqaUiScale.h(12)),
            child,
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white60)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBarChart({
    required List<DateTime> weekDates,
    required List<double> values,
    required List<Color> gradient,
    required List<Color> selectedGradient,
    required String Function(double value) axisFormatter,
    required int? selectedIndex,
    required ValueChanged<int> onTap,
  }) {
    final entries = List<RangedBarChartEntry>.generate(
      weekDates.length,
      (i) => RangedBarChartEntry(
        axisLabel: _weekday(weekDates[i]),
        value: values[i],
      ),
    );
    final max = entries.fold<double>(
      0,
      (current, item) => math.max(current, item.value),
    );
    final maxValue = max <= 0 ? 1.0 : max;
    final midValue = maxValue / 2.0;

    return SizedBox(
      height: TaqaUiScale.h(210),
      child: RangedBarChart(
        entries: entries,
        maxValue: maxValue,
        midValue: midValue,
        formatValue: axisFormatter,
        gradient: gradient,
        selectedGradient: selectedGradient,
        selectedIndex: selectedIndex,
        onBarTap: onTap,
        useFixedSlots: true,
        minBarWidth: TaqaUiScale.w(8),
        gridLineColor: _usesLightMetricDetail
            ? TaqaUiColors.charcoal.withValues(alpha: 0.08)
            : null,
        axisTextColor: _usesLightMetricDetail
            ? TaqaUiColors.charcoal.withValues(alpha: 0.58)
            : Colors.white54,
        labelTextColor: _usesLightMetricDetail
            ? TaqaUiColors.charcoal.withValues(alpha: 0.58)
            : Colors.white54,
      ),
    );
  }

  Widget _buildBarChartEntries({
    required List<RangedBarChartEntry> entries,
    required List<Color> gradient,
    required List<Color> selectedGradient,
    required String Function(double value) axisFormatter,
    required int? selectedIndex,
    required ValueChanged<int> onTap,
    String? yAxisTitle,
  }) {
    final max = entries.fold<double>(
      0,
      (current, item) => math.max(current, item.value),
    );
    final maxValue = max <= 0 ? 1.0 : max;
    final midValue = maxValue / 2.0;
    final chartHeight = (yAxisTitle ?? '').trim().isEmpty ? 210.0 : 242.0;
    return SizedBox(
      height: chartHeight,
      child: RangedBarChart(
        entries: entries,
        maxValue: maxValue,
        midValue: midValue,
        formatValue: axisFormatter,
        gradient: gradient,
        selectedGradient: selectedGradient,
        selectedIndex: selectedIndex,
        onBarTap: onTap,
        useFixedSlots: true,
        minBarWidth: 8,
        yAxisTitle: yAxisTitle,
        gridLineColor: _usesLightMetricDetail
            ? TaqaUiColors.charcoal.withValues(alpha: 0.08)
            : null,
        axisTextColor: _usesLightMetricDetail
            ? TaqaUiColors.charcoal.withValues(alpha: 0.58)
            : Colors.white54,
        labelTextColor: _usesLightMetricDetail
            ? TaqaUiColors.charcoal.withValues(alpha: 0.58)
            : Colors.white54,
      ),
    );
  }

  double _exerciseVolume(Map<String, dynamic> exercise) {
    final compliance = _map(exercise['program_compliance']);
    final sets = _toDouble(
      compliance['performed_sets'] ??
          exercise['performed_sets'] ??
          exercise['sets'],
    );
    final reps = _toDouble(
      compliance['performed_reps'] ??
          exercise['performed_reps'] ??
          exercise['reps'],
    );
    final weight = _toDouble(
      compliance['weight_used'] ?? exercise['weight_used'],
    );
    if (sets <= 0 || reps <= 0 || weight <= 0) return 0;
    final volume = sets * reps * weight;
    return volume.isFinite ? volume : 0;
  }

  Widget _buildLineChart({
    required List<DateTime> weekDates,
    required List<double> values,
    required Color color,
    required String yAxisTitle,
    required String Function(double value) formatYAxis,
  }) {
    final max = values.fold<double>(0, (a, b) => math.max(a, b));
    final top = max <= 0 ? 1.0 : max;
    final mid = top / 2.0;

    return SimpleLineChart(
      values: values.map<double?>((v) => v).toList(),
      color: color,
      showPoints: true,
      xLabels: weekDates.map(_weekday).toList(),
      yLabels: [formatYAxis(top), formatYAxis(mid), formatYAxis(0)],
      xAxisTitle: 'Day',
      yAxisTitle: yAxisTitle,
      labelColor: _usesLightMetricDetail
          ? TaqaUiColors.charcoal.withValues(alpha: 0.58)
          : Colors.white54,
      titleColor: _usesLightMetricDetail
          ? TaqaUiColors.charcoal.withValues(alpha: 0.6)
          : Colors.white60,
      gridColor: _usesLightMetricDetail ? TaqaUiColors.charcoal : Colors.white,
      pointColor: _usesLightMetricDetail ? TaqaUiColors.white : Colors.white,
    );
  }

  Widget _buildWaterStepsContent() {
    final daily = _map(_analyticsData['daily_metrics']);
    final rows = _mapList(daily['last_7_days']);
    final weekDates = _weekDates(
      startRaw: daily['last_7_start']?.toString(),
      endRaw: daily['today']?.toString(),
    );

    final byDate = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final date = _dateOnly(row['entry_date']?.toString());
      if (date == null) continue;
      byDate[_dateKey(date)] = row;
    }

    final steps = <double>[];
    final water = <double>[];
    final sleep = <double>[];
    final calories = <double>[];
    for (final date in weekDates) {
      final row = byDate[_dateKey(date)];
      steps.add(_toInt(row?['steps']).toDouble());
      water.add(_toDouble(row?['water_liters']));
      sleep.add(_toDouble(row?['sleep_hours']));
      calories.add(_toDouble(row?['calories']));
    }

    final totalSteps = steps.fold<double>(0, (sum, value) => sum + value);
    final totalWater = water.fold<double>(0, (sum, value) => sum + value);
    final nonZeroStepDays = steps.where((v) => v > 0).length;
    final avgSteps = nonZeroStepDays == 0
        ? 0.0
        : (totalSteps / nonZeroStepDays);
    final totalSleepHours = sleep.fold<double>(0, (sum, value) => sum + value);
    final totalCalories = calories.fold<double>(0, (sum, value) => sum + value);
    final sleepDays = weekDates.where((day) {
      final row = byDate[_dateKey(day)];
      return row != null && row['sleep_hours'] != null;
    }).length;
    final caloriesDays = weekDates.where((day) {
      final row = byDate[_dateKey(day)];
      return row != null && row['calories'] != null;
    }).length;
    final hasStepsData = weekDates.any((day) {
      final row = byDate[_dateKey(day)];
      return row != null && _toInt(row['steps']) > 0;
    });
    final hasWaterData = weekDates.any((day) {
      final row = byDate[_dateKey(day)];
      return row != null && _toDouble(row['water_liters']) > 0;
    });
    final hasSleepData = weekDates.any((day) {
      final row = byDate[_dateKey(day)];
      return row != null && _toDouble(row['sleep_hours']) > 0;
    });
    final hasCaloriesData = weekDates.any((day) {
      final row = byDate[_dateKey(day)];
      return row != null && _toInt(row['calories']) > 0;
    });
    final avgSleep = sleepDays == 0 ? 0.0 : (totalSleepHours / sleepDays);
    final avgCalories = caloriesDays == 0
        ? 0.0
        : (totalCalories / caloriesDays);
    final hasAnyMetricData =
        hasStepsData || hasWaterData || hasSleepData || hasCaloriesData;

    return ListView(
      padding: TaqaUiScale.insetsLTRB(18, 18, 18, 18),
      children: [
        if (!hasAnyMetricData)
          const TaqaEmptyStateRow(
            text: 'No daily metric data available for this week.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: TaqaUiScale.w(171),
                child: TaqaDashboardMetricCard(
                  source: TaqaDashboardMetricSource.fitbit,
                  title: 'Weekly Steps',
                  valueText: hasStepsData ? _formatCompact(totalSteps) : '0',
                  goalText: hasStepsData
                      ? 'Avg ${_formatCompact(avgSteps)} / day'
                      : 'No data this week',
                  progress: 0,
                  showArc: false,
                  showSourceLogo: false,
                  showArrow: false,
                ),
              ),
              SizedBox(
                width: TaqaUiScale.w(171),
                child: TaqaDashboardMetricCard(
                  source: TaqaDashboardMetricSource.fitbit,
                  title: 'Weekly Water',
                  valueText: hasWaterData
                      ? '${totalWater.toStringAsFixed(1)} L'
                      : '0',
                  goalText: hasWaterData ? 'This week' : 'No data this week',
                  progress: 0,
                  showArc: false,
                  showSourceLogo: false,
                  showArrow: false,
                ),
              ),
              SizedBox(
                width: TaqaUiScale.w(171),
                child: TaqaDashboardMetricCard(
                  source: TaqaDashboardMetricSource.fitbit,
                  title: 'Sleep Avg',
                  valueText: hasSleepData
                      ? '${avgSleep.toStringAsFixed(1)} h'
                      : '0',
                  goalText: hasSleepData
                      ? 'Across $sleepDays day${sleepDays == 1 ? '' : 's'}'
                      : 'No data this week',
                  progress: 0,
                  showArc: false,
                  showSourceLogo: false,
                  showArrow: false,
                ),
              ),
              SizedBox(
                width: TaqaUiScale.w(171),
                child: TaqaDashboardMetricCard(
                  source: TaqaDashboardMetricSource.fitbit,
                  title: 'Calories Avg',
                  valueText: hasCaloriesData
                      ? '${avgCalories.toStringAsFixed(0)} kcal'
                      : '0',
                  goalText: hasCaloriesData
                      ? 'Across $caloriesDays day${caloriesDays == 1 ? '' : 's'}'
                      : 'No data this week',
                  progress: 0,
                  showArc: false,
                  showSourceLogo: false,
                  showArrow: false,
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          _buildChartCard(
            title: 'Steps Trend (7 Days)',
            subtitle: _selectedPrimaryBar == null
                ? 'Tap a bar to inspect a day.'
                : '${_dayDetail(weekDates[_selectedPrimaryBar!])}: ${_formatCompact(steps[_selectedPrimaryBar!])} steps',
            child: _buildBarChart(
              weekDates: weekDates,
              values: steps,
              gradient: const [Color(0xFF35B6FF), Color(0xFF9B8CFF)],
              selectedGradient: const [Color(0xFF5FD8FF), Color(0xFFBAAEFF)],
              axisFormatter: _formatCompact,
              selectedIndex: _selectedPrimaryBar,
              onTap: (index) => setState(() => _selectedPrimaryBar = index),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          _buildChartCard(
            title: 'Water Trend (7 Days)',
            child: _buildBarChart(
              weekDates: weekDates,
              values: water,
              gradient: const [Color(0xFF4BE4C7), Color(0xFF86F0DB)],
              selectedGradient: const [Color(0xFF4BE4C7), Color(0xFF4BE4C7)],
              axisFormatter: (value) => value.toStringAsFixed(1),
              selectedIndex: null,
              onTap: (_) {},
            ),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          _buildChartCard(
            title: 'Sleep Trend (7 Days)',
            child: _buildBarChart(
              weekDates: weekDates,
              values: sleep,
              gradient: const [Color(0xFF8F9DFF), Color(0xFFBBBFFF)],
              selectedGradient: const [Color(0xFF8F9DFF), Color(0xFF8F9DFF)],
              axisFormatter: (value) => value.toStringAsFixed(1),
              selectedIndex: null,
              onTap: (_) {},
            ),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          _buildChartCard(
            title: 'Calories Trend (7 Days)',
            child: _buildBarChart(
              weekDates: weekDates,
              values: calories,
              gradient: const [Color(0xFFFFA85A), Color(0xFFFFC68A)],
              selectedGradient: const [Color(0xFFFFA85A), Color(0xFFFFA85A)],
              axisFormatter: _formatCompact,
              selectedIndex: null,
              onTap: (_) {},
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openTrainingPlanPage() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ExpertTrainingPlanReviewPage(
          clientUserId: widget.clientUserId,
          clientName: widget.clientName,
          clientAvatarUrl: widget.clientAvatarUrl,
          clientActivityStatus: widget.clientActivityStatus,
          activeProgram: _activeProgram,
          trainingPlanError: _trainingPlanError,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final updatedProgramRaw = result['activeProgram'];
    final didCheck = result['didCheck'] == true;
    if (updatedProgramRaw is Map) {
      setState(() {
        _activeProgram = Map<String, dynamic>.from(updatedProgramRaw);
      });
    }
    if (didCheck) {
      widget.onTrainingPlanVerified?.call();
    }
  }

  Widget _buildTrainingPlanPreviewSection() {
    return TaqaFilledButton(
      label: 'Edit Training Plan',
      onTap: _openTrainingPlanPage,
    );
  }

  Widget _buildTrainingCardioContent() {
    final training = _map(_analyticsData['training']);
    final weekDates = _weekDates(
      startRaw: training['last_7_start']?.toString(),
      endRaw: training['today']?.toString(),
    );
    final cardioRows = _mapList(training['recent_cardio_sessions']);

    final cardioStepsByDate = <String, int>{};
    final cardioDistanceByDate = <String, double>{};
    for (final row in cardioRows) {
      final date = _dateOnly(row['entry_date']?.toString());
      if (date == null) continue;
      final key = _dateKey(date);
      cardioStepsByDate[key] =
          (cardioStepsByDate[key] ?? 0) + _toInt(row['steps']);
      cardioDistanceByDate[key] =
          (cardioDistanceByDate[key] ?? 0) + _toDouble(row['distance_km']);
    }

    final cardioSteps = <double>[];
    final cardioDistance = <double>[];
    for (final date in weekDates) {
      final key = _dateKey(date);
      cardioSteps.add((cardioStepsByDate[key] ?? 0).toDouble());
      cardioDistance.add(cardioDistanceByDate[key] ?? 0);
    }

    final selectedWeekHistory = _selectedWeekHistoryEntries();
    final completedExercisesCount = selectedWeekHistory.fold<int>(
      0,
      (sum, entry) => sum + _mapList(entry['completed_exercises']).length,
    );
    final dayVolumeByKey = <String, double>{};
    final dayAdherenceByKey = <String, double>{};
    final dayLabelByKey = <String, String>{};
    final completedTrainingDayByKey = <String, bool>{};
    final startedTrainingDayByKey = <String, bool>{};
    final completedExercisesByDayKey = <String, int>{};
    final totalExercisesByDayKey = <String, int>{};
    final exerciseVolumeByName = <String, double>{};
    int plannedDaysFromHistory = 0;

    String normalizedTrainingDayKey(Map<String, dynamic> dayEntry) {
      final raw = (dayEntry['day_key'] ?? dayEntry['label'] ?? '')
          .toString()
          .trim();
      if (raw.isNotEmpty) return raw.toLowerCase();
      final dayIndex = _toInt(dayEntry['day_index'], fallback: -1);
      if (dayIndex > 0) return 'day_$dayIndex';
      final dateRaw = (dayEntry['latest_date'] ?? '').toString().trim();
      if (dateRaw.isNotEmpty) return 'date_$dateRaw';
      return 'entry_${dayEntry.hashCode}';
    }

    String compactTrainingDayLabel(String raw) {
      final text = raw.trim();
      if (text.isEmpty) return '-';
      if (text.length <= 9) return text;
      final parts = text
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        final acronym = parts
            .take(3)
            .map((p) => p.substring(0, 1).toUpperCase())
            .join();
        if (acronym.length <= 6) return acronym;
      }
      return text.substring(0, 9);
    }

    for (final dayEntry in selectedWeekHistory) {
      final dayDate = _dateOnly(dayEntry['latest_date']?.toString());
      if (dayDate == null) continue;
      final completed = _toInt(dayEntry['completed_count']);
      final total = _toInt(dayEntry['total_count']);
      final planDays = _toInt(dayEntry['plan_days_per_week']);
      if (planDays > plannedDaysFromHistory) {
        plannedDaysFromHistory = planDays;
      }
      final trainingDayKey = normalizedTrainingDayKey(dayEntry);
      final label = (dayEntry['label'] ?? dayEntry['day_key'] ?? 'Training day')
          .toString()
          .trim();
      dayLabelByKey.putIfAbsent(
        trainingDayKey,
        () => label.isEmpty ? 'Training day' : label,
      );
      final dayPct = total > 0
          ? ((completed / total) * 100).clamp(0, 100).toDouble()
          : 0.0;
      final existingPct = dayAdherenceByKey[trainingDayKey] ?? 0.0;
      if (dayPct > existingPct) {
        dayAdherenceByKey[trainingDayKey] = dayPct;
      }
      final existingCompleted = completedExercisesByDayKey[trainingDayKey] ?? 0;
      if (completed > existingCompleted) {
        completedExercisesByDayKey[trainingDayKey] = completed;
      }
      final existingTotal = totalExercisesByDayKey[trainingDayKey] ?? 0;
      if (total > existingTotal) {
        totalExercisesByDayKey[trainingDayKey] = total;
      }
      final isCompletedDay =
          dayEntry['is_completed_day'] == true ||
          (total > 0 && completed >= total);
      completedTrainingDayByKey[trainingDayKey] =
          (completedTrainingDayByKey[trainingDayKey] ?? false) ||
          isCompletedDay;
      final isStartedDay =
          completed > 0 ||
          _mapList(dayEntry['completed_exercises']).isNotEmpty ||
          dayEntry['is_completed_day'] == true;
      startedTrainingDayByKey[trainingDayKey] =
          (startedTrainingDayByKey[trainingDayKey] ?? false) || isStartedDay;

      double dayVolume = 0;
      final exercises = _mapList(dayEntry['completed_exercises']);
      for (final exercise in exercises) {
        final volume = _exerciseVolume(exercise);
        dayVolume += volume;
        final name = (exercise['exercise_name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        exerciseVolumeByName[name] = (exerciseVolumeByName[name] ?? 0) + volume;
      }
      dayVolumeByKey[trainingDayKey] =
          (dayVolumeByKey[trainingDayKey] ?? 0) + dayVolume;
    }

    final plannedDaysFromProgram = _toInt(
      _activeProgram['training_days_per_week'],
    );
    final plannedTrainingDays = plannedDaysFromProgram > 0
        ? plannedDaysFromProgram
        : (_toInt(training['plan_days_per_week']) > 0
              ? _toInt(training['plan_days_per_week'])
              : plannedDaysFromHistory);
    final completedTrainingDays = completedTrainingDayByKey.values
        .where((isDone) => isDone)
        .length;
    final startedTrainingDays = startedTrainingDayByKey.values
        .where((isStarted) => isStarted)
        .length;
    final cappedCompletedTrainingDays = plannedTrainingDays > 0
        ? math.min(completedTrainingDays, plannedTrainingDays)
        : completedTrainingDays;
    final completedExercisesThisWeek = completedExercisesByDayKey.values
        .fold<int>(0, (sum, value) => sum + value);
    final totalExercisesThisWeek = totalExercisesByDayKey.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final weeklyAdherencePct = totalExercisesThisWeek > 0
        ? ((completedExercisesThisWeek / totalExercisesThisWeek) * 100)
              .clamp(0, 100)
              .toDouble()
        : 0.0;
    final trainingDayKeys = dayLabelByKey.keys.toList(growable: false);
    final trainingDayAdherenceEntries = List<RangedBarChartEntry>.generate(
      trainingDayKeys.length,
      (i) => RangedBarChartEntry(
        axisLabel: compactTrainingDayLabel(
          dayLabelByKey[trainingDayKeys[i]] ?? '-',
        ),
        value: dayAdherenceByKey[trainingDayKeys[i]] ?? 0,
      ),
    );
    final trainingDayVolumeEntries = List<RangedBarChartEntry>.generate(
      trainingDayKeys.length,
      (i) => RangedBarChartEntry(
        axisLabel: compactTrainingDayLabel(
          dayLabelByKey[trainingDayKeys[i]] ?? '-',
        ),
        value: dayVolumeByKey[trainingDayKeys[i]] ?? 0,
      ),
    );
    final selectedAdherenceIndex =
        (_selectedAdherenceBar != null &&
            _selectedAdherenceBar! >= 0 &&
            _selectedAdherenceBar! < trainingDayAdherenceEntries.length)
        ? _selectedAdherenceBar
        : null;

    final exerciseVolumesSorted = exerciseVolumeByName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final exerciseVolumeEntries = List<RangedBarChartEntry>.generate(
      exerciseVolumesSorted.length > 8 ? 8 : exerciseVolumesSorted.length,
      (i) => RangedBarChartEntry(
        axisLabel: '${i + 1}',
        value: exerciseVolumesSorted[i].value,
      ),
    );
    final selectedDayVolumeIndex =
        (_selectedTrainingDayVolumeBar != null &&
            _selectedTrainingDayVolumeBar! >= 0 &&
            _selectedTrainingDayVolumeBar! < trainingDayVolumeEntries.length)
        ? _selectedTrainingDayVolumeBar
        : null;
    final selectedExerciseVolumeIndex =
        (_selectedExerciseVolumeBar != null &&
            _selectedExerciseVolumeBar! >= 0 &&
            _selectedExerciseVolumeBar! < exerciseVolumeEntries.length)
        ? _selectedExerciseVolumeBar
        : null;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSummaryPill(
              label: 'Days Started',
              value: '$startedTrainingDays',
              accent: const Color(0xFF5FD8FF),
            ),
            _buildSummaryPill(
              label: 'Days Done',
              value: '$cappedCompletedTrainingDays',
              accent: const Color(0xFF5FD8FF),
            ),
            _buildSummaryPill(
              label: 'Training Exercises',
              value: '${_toInt(training['training_items_done'])}',
              accent: const Color(0xFFA4AEFF),
            ),
            _buildSummaryPill(
              label: 'Train Plan',
              value: plannedTrainingDays > 0
                  ? '$plannedTrainingDays days'
                  : '-',
              accent: const Color(0xFF7ED7A7),
            ),
            _buildSummaryPill(
              label: 'Weekly Adherence',
              value: '${weeklyAdherencePct.toStringAsFixed(0)}%',
              accent: const Color(0xFFFFA85A),
            ),
            _buildSummaryPill(
              label: 'Cardio Sessions',
              value: '${_toInt(training['cardio_sessions_done'])}',
              accent: const Color(0xFF4BE4C7),
            ),
            _buildSummaryPill(
              label: 'Cardio Distance',
              value:
                  '${_toDouble(training['cardio_distance_km']).toStringAsFixed(1)} km',
              accent: const Color(0xFFF7B267),
            ),
            _buildSummaryPill(
              label: 'Cardio Steps',
              value: _formatCompact(
                _toInt(training['cardio_steps']).toDouble(),
              ),
              accent: const Color(0xFF73C2FF),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTrainingPlanPreviewSection(),
        const SizedBox(height: 12),
        TaqaClientDashboardNavigationCard(
          title: 'Training History',
          description:
              '${selectedWeekHistory.length} training day(s), $completedExercisesCount completed exercise(s)',
          onTap: () => _openAllExercisesDonePage(selectedWeekHistory),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Volume Trend per Training Day',
          subtitle: selectedDayVolumeIndex == null
              ? 'Tap a bar to inspect a training day.'
              : '${dayLabelByKey[trainingDayKeys[selectedDayVolumeIndex]]}: ${_formatCompact(dayVolumeByKey[trainingDayKeys[selectedDayVolumeIndex]] ?? 0)}',
          child: trainingDayVolumeEntries.isEmpty
              ? const Text(
                  'No training-day volume data for this week.',
                  style: TextStyle(color: TaqaUiColors.charcoal),
                )
              : _buildBarChartEntries(
                  entries: trainingDayVolumeEntries,
                  gradient: const [Color(0xFF3BC7FF), Color(0xFF72E6B4)],
                  selectedGradient: const [
                    Color(0xFF67DCFF),
                    Color(0xFF95F2CA),
                  ],
                  axisFormatter: (v) => _formatCompact(v),
                  selectedIndex: selectedDayVolumeIndex,
                  onTap: (i) =>
                      setState(() => _selectedTrainingDayVolumeBar = i),
                  yAxisTitle: 'kg',
                ),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Volume Trend per Exercise',
          subtitle: selectedExerciseVolumeIndex == null
              ? 'Bars show top exercises by weekly volume. Tap a bar for details.'
              : '${exerciseVolumesSorted[selectedExerciseVolumeIndex].key}: ${_formatCompact(exerciseVolumesSorted[selectedExerciseVolumeIndex].value)}',
          child: exerciseVolumeEntries.isEmpty
              ? const Text(
                  'No volume data available for this week.',
                  style: TextStyle(color: TaqaUiColors.charcoal),
                )
              : _buildBarChartEntries(
                  entries: exerciseVolumeEntries,
                  gradient: const [Color(0xFF6A7CFF), Color(0xFF9F7BFF)],
                  selectedGradient: const [
                    Color(0xFF8A97FF),
                    Color(0xFFB399FF),
                  ],
                  axisFormatter: (v) => _formatCompact(v),
                  selectedIndex: selectedExerciseVolumeIndex,
                  onTap: (i) => setState(() => _selectedExerciseVolumeBar = i),
                  yAxisTitle: 'kg',
                ),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Adherence Rate per Training Day',
          subtitle: selectedAdherenceIndex == null
              ? 'Tap a bar to inspect a training day.'
              : '${dayLabelByKey[trainingDayKeys[selectedAdherenceIndex]]}: ${(dayAdherenceByKey[trainingDayKeys[selectedAdherenceIndex]] ?? 0).toStringAsFixed(0)}%',
          child: trainingDayAdherenceEntries.isEmpty
              ? const Text(
                  'No training-day adherence data for this week.',
                  style: TextStyle(color: TaqaUiColors.charcoal),
                )
              : _buildBarChartEntries(
                  entries: trainingDayAdherenceEntries,
                  gradient: const [Color(0xFFFFB161), Color(0xFFFF7D6A)],
                  selectedGradient: const [
                    Color(0xFFFFC98A),
                    Color(0xFFFF9E91),
                  ],
                  axisFormatter: (v) => '${v.toStringAsFixed(0)}%',
                  selectedIndex: selectedAdherenceIndex,
                  onTap: (i) => setState(() => _selectedAdherenceBar = i),
                ),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Cardio Sessions Steps',
          child: _buildLineChart(
            weekDates: weekDates,
            values: cardioSteps,
            color: const Color(0xFF4BE4C7),
            yAxisTitle: 'Steps',
            formatYAxis: (v) => _formatCompact(v),
          ),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Cardio Sessions Distance',
          child: _buildLineChart(
            weekDates: weekDates,
            values: cardioDistance,
            color: const Color(0xFFF7B267),
            yAxisTitle: 'KM',
            formatYAxis: (v) => v.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }

  Map<String, Map<String, dynamic>> _rowsByDate(
    List<Map<String, dynamic>> rows,
  ) {
    final out = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final date = _dateOnly(row['entry_date']?.toString());
      if (date == null) continue;
      out[_dateKey(date)] = row;
    }
    return out;
  }

  bool _hasMetricForWeek({
    required List<DateTime> weekDates,
    required Map<String, Map<String, dynamic>> byDate,
    required String key,
  }) {
    for (final day in weekDates) {
      final row = byDate[_dateKey(day)];
      if (row != null && row[key] != null) return true;
    }
    return false;
  }

  List<double> _metricValuesForWeek({
    required List<DateTime> weekDates,
    required Map<String, Map<String, dynamic>> byDate,
    required String key,
    double multiplier = 1.0,
  }) {
    return weekDates
        .map((day) {
          final row = byDate[_dateKey(day)];
          return _toDouble(row?[key]) * multiplier;
        })
        .toList(growable: false);
  }

  Widget _buildWearablesContent() {
    final daily = _map(_analyticsData['daily_metrics']);
    final wearables = _map(_analyticsData['wearables']);
    final whoop = _map(wearables['whoop']);
    final fitbit = _map(wearables['fitbit']);
    final whoopRows = _mapList(whoop['last_7_days']);
    final fitbitRows = _mapList(fitbit['last_7_days']);
    final whoopByDate = _rowsByDate(whoopRows);
    final fitbitByDate = _rowsByDate(fitbitRows);
    final weekDates = _weekDates(
      startRaw: daily['last_7_start']?.toString(),
      endRaw: daily['today']?.toString(),
    );

    final effectiveProvider = _selectedWearableProvider;
    final showWhoopCharts = effectiveProvider == _wearableWhoop;
    final showFitbitCharts = effectiveProvider == _wearableFitbit;
    final selectedIndex =
        (_selectedPrimaryBar != null &&
            _selectedPrimaryBar! >= 0 &&
            _selectedPrimaryBar! < weekDates.length)
        ? _selectedPrimaryBar
        : null;

    Widget? metricCard({
      required String title,
      required Map<String, Map<String, dynamic>> byDate,
      required String key,
      required List<Color> gradient,
      required List<Color> selectedGradient,
      required String Function(double value) formatValue,
      double multiplier = 1.0,
    }) {
      final hasData = _hasMetricForWeek(
        weekDates: weekDates,
        byDate: byDate,
        key: key,
      );
      if (!hasData) return null;
      final values = _metricValuesForWeek(
        weekDates: weekDates,
        byDate: byDate,
        key: key,
        multiplier: multiplier,
      );
      return _buildChartCard(
        title: title,
        subtitle: selectedIndex == null
            ? 'Tap a bar to inspect a day.'
            : '${_dayDetail(weekDates[selectedIndex])}: ${formatValue(values[selectedIndex])}',
        child: _buildBarChart(
          weekDates: weekDates,
          values: values,
          gradient: gradient,
          selectedGradient: selectedGradient,
          axisFormatter: formatValue,
          selectedIndex: selectedIndex,
          onTap: (i) => setState(() => _selectedPrimaryBar = i),
        ),
      );
    }

    final chartCards = <Widget>[
      ...[
        if (showWhoopCharts) ...[
          metricCard(
            title: 'Whoop Recovery (7 Days)',
            byDate: whoopByDate,
            key: 'recovery_score',
            gradient: const [Color(0xFF3BC7FF), Color(0xFF67F3C9)],
            selectedGradient: const [Color(0xFF6FDCFF), Color(0xFF96FFE1)],
            formatValue: (v) => v.toStringAsFixed(0),
          ),
          metricCard(
            title: 'Whoop Strain (7 Days)',
            byDate: whoopByDate,
            key: 'strain',
            gradient: const [Color(0xFF5D9CFF), Color(0xFF9C7DFF)],
            selectedGradient: const [Color(0xFF80B7FF), Color(0xFFB49BFF)],
            formatValue: (v) => v.toStringAsFixed(1),
          ),
          metricCard(
            title: 'Whoop Sleep (Hours)',
            byDate: whoopByDate,
            key: 'total_sleep_minutes',
            multiplier: 1 / 60,
            gradient: const [Color(0xFF6A7CFF), Color(0xFF6BD6FF)],
            selectedGradient: const [Color(0xFF8A97FF), Color(0xFF93E4FF)],
            formatValue: _formatSleepHoursLabel,
          ),
        ],
        if (showFitbitCharts) ...[
          metricCard(
            title: 'Fitbit Sleep (Hours)',
            byDate: fitbitByDate,
            key: 'sleep_minutes_asleep',
            multiplier: 1 / 60,
            gradient: const [Color(0xFF4B8EFF), Color(0xFF4BE4C7)],
            selectedGradient: const [Color(0xFF6AA2FF), Color(0xFF75EDD6)],
            formatValue: _formatSleepHoursLabel,
          ),
          metricCard(
            title: 'Fitbit Active Minutes (7 Days)',
            byDate: fitbitByDate,
            key: 'active_minutes',
            gradient: const [Color(0xFF4BE4C7), Color(0xFF79E7B3)],
            selectedGradient: const [Color(0xFF76F1D7), Color(0xFFA0F4CC)],
            formatValue: (v) => v.toStringAsFixed(0),
          ),
          metricCard(
            title: 'Fitbit Steps (7 Days)',
            byDate: fitbitByDate,
            key: 'steps',
            gradient: const [Color(0xFF3BC7FF), Color(0xFF7C8BFF)],
            selectedGradient: const [Color(0xFF6FDCFF), Color(0xFFA1ADFF)],
            formatValue: _formatCompact,
          ),
        ],
      ].whereType<Widget>(),
    ];

    return ListView(
      padding: TaqaUiScale.insetsLTRB(16, 0, 16, 24),
      children: [
        SizedBox(height: TaqaUiScale.h(12)),
        Row(
          children: [
            Expanded(
              child: TaqaPillTab(
                label: 'Whoop',
                active: effectiveProvider == _wearableWhoop,
                onTap: () => setState(() {
                  _selectedWearableProvider = _wearableWhoop;
                  _selectedPrimaryBar = null;
                }),
              ),
            ),
            SizedBox(width: TaqaUiScale.w(8)),
            Expanded(
              child: TaqaPillTab(
                label: 'Fitbit',
                active: effectiveProvider == _wearableFitbit,
                onTap: () => setState(() {
                  _selectedWearableProvider = _wearableFitbit;
                  _selectedPrimaryBar = null;
                }),
              ),
            ),
          ],
        ),
        SizedBox(height: TaqaUiScale.h(12)),
        if (chartCards.isEmpty)
          const TaqaEmptyStateRow(
            text: 'No wearable metrics available for this week.',
          )
        else
          ...List<Widget>.generate(chartCards.length, (index) {
            if (index == 0) return chartCards[index];
            return Column(
              children: [
                SizedBox(height: TaqaUiScale.h(12)),
                chartCards[index],
              ],
            );
          }),
      ],
    );
  }

  void _openAllExercisesDonePage(List<Map<String, dynamic>> weekEntries) {
    final training = _map(_analyticsData['training']);
    final plannedDays = _toInt(_activeProgram['training_days_per_week']) > 0
        ? _toInt(_activeProgram['training_days_per_week'])
        : _toInt(training['plan_days_per_week']);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
          appBar: TaqaPageAppBar(
            title: 'Training History',
            backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
            titleColor: TaqaUiColors.charcoal,
            leading: const TaqaBackButton(color: TaqaUiColors.charcoal),
          ),
          body: ListView(
            padding: TaqaUiScale.insetsLTRB(16, 12, 16, 24),
            children: [
              TaqaExpertClientCard(
                name: widget.clientName,
                avatarUrl: widget.clientAvatarUrl,
                status: widget.clientActivityStatus,
                showStatus: (widget.clientActivityStatus ?? '')
                    .trim()
                    .isNotEmpty,
                subtitle: 'User ID: ${widget.clientUserId}',
                details: ['Days/week: ${plannedDays > 0 ? plannedDays : '-'}'],
                alerts: const [],
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              _buildSelectedWeekExercisesContent(weekEntries),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _selectedTrainingWeekStart() {
    final training = _map(_analyticsData['training']);
    return _dateOnly(training['week_start']?.toString()) ??
        _dateOnly(training['last_7_start']?.toString());
  }

  List<Map<String, dynamic>> _selectedWeekHistoryEntries() {
    final selectedWeekStart = _selectedTrainingWeekStart();
    if (selectedWeekStart == null) return const [];
    final targetKey = _dateKey(selectedWeekStart);
    final out = _exerciseHistoryEntries.where((entry) {
      final weekStart = _dateOnly(entry['week_start']?.toString());
      if (weekStart == null) return false;
      return _dateKey(weekStart) == targetKey;
    }).toList();
    out.sort((a, b) {
      final aRaw = (a['latest_date'] ?? '').toString().trim();
      final bRaw = (b['latest_date'] ?? '').toString().trim();
      final aDate = DateTime.tryParse(aRaw);
      final bDate = DateTime.tryParse(bRaw);
      if (aDate != null && bDate != null) return bDate.compareTo(aDate);
      return bRaw.compareTo(aRaw);
    });
    return out;
  }

  Widget _buildSelectedWeekExercisesContent(
    List<Map<String, dynamic>> weekEntries,
  ) {
    if (_loadingExerciseHistory) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: TaqaUiColors.charcoal,
          ),
        ),
      );
    }
    if (_exerciseHistoryError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _exerciseHistoryError!,
            style: const TextStyle(color: TaqaUiColors.charcoal),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadExerciseHistory,
            style: OutlinedButton.styleFrom(
              foregroundColor: TaqaUiColors.charcoal,
              side: BorderSide(
                color: TaqaUiColors.charcoal.withValues(alpha: 0.2),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (weekEntries.isEmpty) {
      return const Text(
        'No exercises logged.',
        style: TextStyle(color: TaqaUiColors.charcoal),
      );
    }
    return Column(
      children: weekEntries.map((entry) {
        final label = (entry['label'] ?? entry['day_label'] ?? 'Training day')
            .toString();
        final sessionDate = _dateOnly(
          entry['session_date']?.toString() ?? entry['latest_date']?.toString(),
        );
        final completedCount = _toInt(entry['completed_count']);
        final totalCount = _toInt(entry['total_count']);
        final completedExercises = _mapList(entry['completed_exercises']);
        final sessionStats = _computeSessionDayStats(
          completedExercises,
          sessionDate: sessionDate,
        );
        final restBetweenExercisesLabel =
            sessionStats.restBetweenExerciseTransitions > 0
            ? '${_formatSecondsCompact(sessionStats.restBetweenExercisesSeconds)} total • ${_formatSecondsCompact(sessionStats.avgRestBetweenExercisesSeconds)} avg'
            : (completedExercises.length > 1 ? 'Insufficient timestamps' : '-');
        final dateLabel = sessionDate == null
            ? _weekRangeLabel()
            : DateFormat('dd MMM yyyy').format(sessionDate);

        return Padding(
          padding: EdgeInsets.only(bottom: TaqaUiScale.h(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: TaqaUiColors.charcoal,
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w700,
                  height: 25 / 15,
                  letterSpacing: 0,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$completedCount/$totalCount completed',
                    style: TextStyle(
                      color: TaqaUiColors.charcoal,
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w400,
                      height: 25 / 15,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: TaqaUiColors.charcoal,
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w400,
                      height: 25 / 15,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              TaqaProfileInfoSection(
                title: 'Overall Stats',
                items: [
                  TaqaProfileInfoItem(
                    label: 'Session',
                    value: sessionStats.sessionSeconds > 0
                        ? _formatSecondsCompact(sessionStats.sessionSeconds)
                        : '-',
                  ),
                  TaqaProfileInfoItem(
                    label: 'Active',
                    value: sessionStats.activeSeconds > 0
                        ? _formatSecondsCompact(sessionStats.activeSeconds)
                        : '-',
                  ),
                  TaqaProfileInfoItem(
                    label: 'Rest Between Exercises',
                    value: restBetweenExercisesLabel,
                  ),
                ],
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              if (completedExercises.isEmpty)
                Text(
                  'No completed exercises.',
                  style: TextStyle(
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                  ),
                )
              else
                ...completedExercises.map((exercise) {
                  final exerciseName = (exercise['exercise_name'] ?? 'Exercise')
                      .toString();
                  final loggedAt = _exerciseLoggedDateLabel(exercise) ?? '-';
                  return Padding(
                    padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                    child: TaqaProfileInfoSection(
                      title: exerciseName,
                      items: [
                        TaqaProfileInfoItem(
                          label: 'Duration',
                          value: _exerciseDurationLabel(exercise),
                        ),
                        TaqaProfileInfoItem(
                          label: 'Set Rest',
                          value: _exerciseRestLabel(exercise),
                        ),
                        TaqaProfileInfoItem(
                          label: 'Weight',
                          value: _exerciseWeightLabel(exercise),
                        ),
                        TaqaProfileInfoItem(label: 'Logged', value: loggedAt),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Kept for now because the detailed session timing calculations may be
  // reused in a future expert-specific drill-down. The active route uses the
  // shared client training-history day detail instead.
  // ignore: unused_element
  Widget _buildWeekExerciseDayBlock(Map<String, dynamic> entry) {
    final label = (entry['label'] ?? entry['day_label'] ?? 'Training day')
        .toString();
    final sessionDate = _dateOnly(
      entry['session_date']?.toString() ?? entry['latest_date']?.toString(),
    );
    final sessionDateLabel = sessionDate == null
        ? null
        : DateFormat('dd MMM yyyy').format(sessionDate);
    final completedCount = _toInt(entry['completed_count']);
    final totalCount = _toInt(entry['total_count']);
    final exercises = _mapList(entry['completed_exercises']);
    final sessionStats = _computeSessionDayStats(
      exercises,
      sessionDate: sessionDate,
    );
    final sessionSeconds = sessionStats.sessionSeconds;
    final activeSeconds = sessionStats.activeSeconds;
    final restBetweenExercisesSeconds =
        sessionStats.restBetweenExercisesSeconds;
    final restBetweenExerciseTransitions =
        sessionStats.restBetweenExerciseTransitions;
    final avgRestBetweenExercisesSeconds =
        sessionStats.avgRestBetweenExercisesSeconds;
    final sessionDurationLabel = sessionSeconds > 0
        ? _formatSecondsCompact(sessionSeconds)
        : '-';
    final activeDurationLabel = activeSeconds > 0
        ? _formatSecondsCompact(activeSeconds)
        : '-';
    final restBetweenExercisesLabel = restBetweenExerciseTransitions > 0
        ? '${_formatSecondsCompact(restBetweenExercisesSeconds)} total • ${_formatSecondsCompact(avgRestBetweenExercisesSeconds)} avg'
        : (exercises.length > 1 ? 'Insufficient timestamps' : '-');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (sessionDateLabel != null)
                Text(
                  sessionDateLabel,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount/$totalCount completed',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    'Session: $sessionDurationLabel',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Active: $activeDurationLabel',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Rest between exercises: $restBetweenExercisesLabel',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...exercises.map((exercise) {
              final title = (exercise['exercise_name'] ?? '').toString().trim();
              final compliance = _map(exercise['program_compliance']);
              final sets = _exerciseValueAsText(
                compliance['performed_sets'] ??
                    exercise['performed_sets'] ??
                    exercise['sets'],
              );
              final reps = _exerciseValueAsText(
                compliance['performed_reps'] ??
                    exercise['performed_reps'] ??
                    exercise['reps'],
              );
              final rir = _exerciseValueAsText(
                compliance['performed_rir'] ??
                    exercise['performed_rir'] ??
                    exercise['rir'],
              );
              final loggedAtLabel = _exerciseLoggedDateLabel(exercise);
              final durationLabel = _exerciseDurationLabel(exercise);
              final restLabel = _exerciseRestLabel(exercise);
              final weightLabel = _exerciseWeightLabel(exercise);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.isEmpty ? 'Exercise' : title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$sets x $reps',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RIR $rir',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Duration: $durationLabel',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Set rest: $restLabel',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Weight: $weightLabel',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (loggedAtLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Logged: $loggedAtLabel',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _exerciseValueAsText(dynamic value) {
    if (value == null) return '-';
    if (value is int) return value <= 0 ? '-' : '$value';
    if (value is num) {
      if (value <= 0) return '-';
      final asInt = value.toInt();
      return asInt.toDouble() == value.toDouble()
          ? '$asInt'
          : value.toStringAsFixed(1);
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == '0') return '-';
    return text;
  }

  String? _exerciseLoggedDateLabel(Map<String, dynamic> exercise) {
    final compliance = _map(exercise['program_compliance']);
    final raw = (compliance['logged_at'] ?? exercise['logged_at'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }

  String _exerciseDurationLabel(Map<String, dynamic> exercise) {
    final compliance = _map(exercise['program_compliance']);
    final seconds = _toInt(
      compliance['performed_time_seconds'] ??
          exercise['performed_time_seconds'],
      fallback: -1,
    );
    if (seconds <= 0) return '-';
    return _formatSecondsCompact(seconds);
  }

  DateTime? _exerciseLoggedAtDateTime(Map<String, dynamic> exercise) {
    final compliance = _map(exercise['program_compliance']);
    final raw =
        (compliance['logged_at'] ??
                exercise['logged_at'] ??
                exercise['completed_at'] ??
                '')
            .toString()
            .trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  _SessionDayStats _computeSessionDayStats(
    List<Map<String, dynamic>> exercises, {
    DateTime? sessionDate,
  }) {
    const maxExerciseDurationSeconds = 4 * 60 * 60;
    const maxBetweenExerciseGapSeconds = 3 * 60 * 60;
    int activeSeconds = 0;
    final timeline = <_ExerciseTimelinePoint>[];

    for (final exercise in exercises) {
      final compliance = _map(exercise['program_compliance']);
      final durationSeconds = _toInt(
        compliance['performed_time_seconds'] ??
            exercise['performed_time_seconds'],
        fallback: 0,
      );
      if (durationSeconds <= 0 ||
          durationSeconds > maxExerciseDurationSeconds) {
        continue;
      }
      if (durationSeconds > 0) {
        activeSeconds += durationSeconds;
      }
      final loggedAt = _exerciseLoggedAtDateTime(exercise);
      if (loggedAt != null && durationSeconds > 0) {
        final end = loggedAt;
        final start = end.subtract(Duration(seconds: durationSeconds));
        if (sessionDate != null) {
          final startDateOnly = DateTime(start.year, start.month, start.day);
          final endDateOnly = DateTime(end.year, end.month, end.day);
          if (startDateOnly != sessionDate && endDateOnly != sessionDate) {
            continue;
          }
        }
        timeline.add(_ExerciseTimelinePoint(start: start, end: end));
      }
    }

    if (timeline.isEmpty) {
      return _SessionDayStats(
        activeSeconds: activeSeconds,
        sessionSeconds: activeSeconds,
        restBetweenExercisesSeconds: 0,
        restBetweenExerciseTransitions: 0,
        avgRestBetweenExercisesSeconds: 0,
      );
    }

    timeline.sort((a, b) => a.start.compareTo(b.start));
    final overallStart = timeline.first.start;
    var overallEnd = timeline.first.end;
    var previousEnd = timeline.first.end;
    int restBetweenExercisesSeconds = 0;
    int restBetweenExerciseTransitions = 0;

    for (var i = 1; i < timeline.length; i++) {
      final current = timeline[i];
      if (current.start.isAfter(previousEnd)) {
        final gap = current.start.difference(previousEnd).inSeconds;
        if (gap > 0 && gap <= maxBetweenExerciseGapSeconds) {
          restBetweenExercisesSeconds += gap;
          restBetweenExerciseTransitions += 1;
        }
      }
      if (current.end.isAfter(previousEnd)) {
        previousEnd = current.end;
      }
      if (current.end.isAfter(overallEnd)) {
        overallEnd = current.end;
      }
    }

    var sessionSeconds = activeSeconds + restBetweenExercisesSeconds;
    if (sessionSeconds <= 0) {
      sessionSeconds = overallEnd.difference(overallStart).inSeconds;
    }
    if (sessionSeconds < activeSeconds) {
      sessionSeconds = activeSeconds;
    }

    final avgRestBetweenExercisesSeconds = restBetweenExerciseTransitions > 0
        ? (restBetweenExercisesSeconds / restBetweenExerciseTransitions).round()
        : 0;

    return _SessionDayStats(
      activeSeconds: activeSeconds,
      sessionSeconds: sessionSeconds,
      restBetweenExercisesSeconds: restBetweenExercisesSeconds,
      restBetweenExerciseTransitions: restBetweenExerciseTransitions,
      avgRestBetweenExercisesSeconds: avgRestBetweenExercisesSeconds,
    );
  }

  String _exerciseRestLabel(Map<String, dynamic> exercise) {
    final compliance = _map(exercise['program_compliance']);
    final seconds = _toInt(
      compliance['rest_before_seconds'] ?? exercise['rest_before_seconds'],
      fallback: -1,
    );
    if (seconds <= 0) return '-';
    return _formatSecondsCompact(seconds);
  }

  String _exerciseWeightLabel(Map<String, dynamic> exercise) {
    final compliance = _map(exercise['program_compliance']);
    final weight = _toDouble(
      compliance['weight_used'] ?? exercise['weight_used'],
      fallback: -1,
    );
    if (weight <= 0) return '-';
    final roundedInt = weight.roundToDouble();
    final compact = (weight - roundedInt).abs() < 0.001
        ? '${roundedInt.toInt()}'
        : weight.toStringAsFixed(1);
    return '$compact kg';
  }

  String _formatSecondsCompact(int seconds) {
    if (seconds <= 0) return '-';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      if (m > 0) return '${h}h ${m}m';
      return '${h}h';
    }
    if (m > 0) {
      if (s > 0) return '${m}m ${s}s';
      return '${m}m';
    }
    return '${s}s';
  }

  String _formatSleepHoursLabel(double hours) {
    if (!hours.isFinite || hours <= 0) return '0m';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isWater = widget.type == ExpertWeeklyMetricsDetailType.waterSteps;
    final isTraining =
        widget.type == ExpertWeeklyMetricsDetailType.trainingCardio;
    final usesClientHeader =
        isTraining ||
        isWater ||
        widget.type == ExpertWeeklyMetricsDetailType.wearables;
    final title = isWater
        ? 'Daily Metrics Details'
        : (isTraining ? 'Training & Cardio Details' : 'Wearables Details');

    return Scaffold(
      backgroundColor: usesClientHeader
          ? TaqaUiColors.unnamedColorE3e3e3
          : AppColors.black,
      appBar: TaqaPageAppBar(
        title: title,
        backgroundColor: usesClientHeader
            ? TaqaUiColors.unnamedColorE3e3e3
            : AppColors.black,
        titleColor: usesClientHeader ? TaqaUiColors.charcoal : Colors.white,
        leading: TaqaBackButton(
          color: usesClientHeader ? TaqaUiColors.charcoal : Colors.white,
        ),
      ),
      body: Column(
        children: [
          if (usesClientHeader)
            Padding(
              padding: TaqaUiScale.insetsLTRB(16, 12, 17, 0),
              child: TaqaExpertClientCard(
                name: widget.clientName,
                avatarUrl: widget.clientAvatarUrl,
                status: widget.clientActivityStatus,
                showStatus: (widget.clientActivityStatus ?? '')
                    .trim()
                    .isNotEmpty,
                subtitle: 'User ID: ${widget.clientUserId}',
                details: (isWater || !isTraining)
                    ? const ['Weekly (7 days)']
                    : const [],
                alerts: const [],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.clientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Weekly (7 days)',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          _buildWeekSwitcher(),
          if (_weekError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                _weekError!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          Expanded(
            child: isWater
                ? _buildWaterStepsContent()
                : (isTraining
                      ? _buildTrainingCardioContent()
                      : _buildWearablesContent()),
          ),
        ],
      ),
    );
  }
}

class ClientWeeklyMetricDetailPage extends StatelessWidget {
  const ClientWeeklyMetricDetailPage({
    super.key,
    required this.title,
    required this.clientName,
    required this.clientUserId,
    required this.clientAvatarUrl,
    required this.clientActivityStatus,
    required this.values,
    required this.dates,
    required this.color,
    required this.unit,
    required this.formatValue,
  });

  final String title;
  final String clientName;
  final int clientUserId;
  final String? clientAvatarUrl;
  final String? clientActivityStatus;
  final List<double> values;
  final List<DateTime> dates;
  final Color color;
  final String unit;
  final String Function(double value) formatValue;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, math.max);
    final top = max <= 0 ? 1.0 : max;
    final mid = top / 2;
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
          TaqaExpertClientCard(
            name: clientName,
            avatarUrl: clientAvatarUrl,
            status: clientActivityStatus,
            showStatus: (clientActivityStatus ?? '').trim().isNotEmpty,
            subtitle: 'User ID: $clientUserId',
            details: const ['Weekly (7 days)'],
            alerts: const [],
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaClientDashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaqaClientDashboardTitleText('$title (Last 7 Days)'),
                SizedBox(height: TaqaUiScale.h(12)),
                SizedBox(
                  height: TaqaUiScale.h(242),
                  child: RangedBarChart(
                    entries: List<RangedBarChartEntry>.generate(
                      values.length,
                      (index) => RangedBarChartEntry(
                        axisLabel: DateFormat('EEE').format(dates[index]),
                        value: values[index],
                      ),
                    ),
                    maxValue: top,
                    midValue: mid,
                    formatValue: formatValue,
                    gradient: [color, color.withValues(alpha: 0.58)],
                    selectedGradient: [color, color],
                    useFixedSlots: true,
                    minBarWidth: TaqaUiScale.w(8),
                    yAxisTitle: unit,
                    gridLineColor: TaqaUiColors.charcoal.withValues(
                      alpha: 0.08,
                    ),
                    axisTextColor: TaqaUiColors.charcoal.withValues(
                      alpha: 0.58,
                    ),
                    labelTextColor: TaqaUiColors.charcoal.withValues(
                      alpha: 0.58,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTimelinePoint {
  const _ExerciseTimelinePoint({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class _SessionDayStats {
  const _SessionDayStats({
    required this.activeSeconds,
    required this.sessionSeconds,
    required this.restBetweenExercisesSeconds,
    required this.restBetweenExerciseTransitions,
    required this.avgRestBetweenExercisesSeconds,
  });

  final int activeSeconds;
  final int sessionSeconds;
  final int restBetweenExercisesSeconds;
  final int restBetweenExerciseTransitions;
  final int avgRestBetweenExercisesSeconds;
}
