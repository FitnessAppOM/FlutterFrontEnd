import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/ranged_bar_chart.dart';
import '../widgets/charts/simple_line_chart.dart';

enum ExpertWeeklyMetricsDetailType { waterSteps, trainingCardio, wearables }

class ExpertWeeklyMetricsDetailPage extends StatefulWidget {
  const ExpertWeeklyMetricsDetailPage({
    super.key,
    required this.type,
    required this.clientUserId,
    required this.clientName,
    required this.analyticsData,
  });

  final ExpertWeeklyMetricsDetailType type;
  final int clientUserId;
  final String clientName;
  final Map<String, dynamic> analyticsData;

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
  final Map<int, Map<String, dynamic>> _weeklyCache =
      <int, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _analyticsData = Map<String, dynamic>.from(widget.analyticsData);
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
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
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
        _weekError = e.toString();
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
        _exerciseHistoryError = e.toString().replaceFirst('Exception: ', '');
        _loadingExerciseHistory = false;
      });
    }
  }

  Widget _buildWeekSwitcher() {
    final canGoNext = _weekOffset > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _loadingWeek ? null : () => _changeWeek(_weekOffset + 1),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            child: const Text('Prev'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _loadingWeek || !canGoNext
                ? null
                : () => _changeWeek(_weekOffset - 1),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            child: const Text('Next'),
          ),
          const Spacer(),
          if (_loadingWeek)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              _weekRangeLabel(),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
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
      height: 210,
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
    return SizedBox(
      height: 210,
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
    return sets * reps * weight;
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
      return row != null && row['steps'] != null;
    });
    final hasWaterData = weekDates.any((day) {
      final row = byDate[_dateKey(day)];
      return row != null && row['water_liters'] != null;
    });
    final hasSleepData = weekDates.any((day) {
      final row = byDate[_dateKey(day)];
      return row != null && row['sleep_hours'] != null;
    });
    final hasCaloriesData = weekDates.any((day) {
      final row = byDate[_dateKey(day)];
      return row != null && row['calories'] != null;
    });
    final avgSleep = sleepDays == 0 ? 0.0 : (totalSleepHours / sleepDays);
    final avgCalories = caloriesDays == 0
        ? 0.0
        : (totalCalories / caloriesDays);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (hasStepsData)
              _buildSummaryPill(
                label: 'Weekly Steps',
                value: _formatCompact(totalSteps),
                accent: const Color(0xFF63D5FF),
              ),
            if (hasStepsData)
              _buildSummaryPill(
                label: 'Average Steps/Active Day',
                value: _formatCompact(avgSteps),
                accent: const Color(0xFF9DA6FF),
              ),
            if (hasWaterData)
              _buildSummaryPill(
                label: 'Weekly Water',
                value: '${totalWater.toStringAsFixed(1)} L',
                accent: const Color(0xFF4BE4C7),
              ),
            if (hasSleepData)
              _buildSummaryPill(
                label: 'Sleep Avg',
                value: '${avgSleep.toStringAsFixed(1)} h',
                accent: const Color(0xFF8F9DFF),
              ),
            if (hasCaloriesData)
              _buildSummaryPill(
                label: 'Calories Avg',
                value: '${avgCalories.toStringAsFixed(0)} kcal',
                accent: const Color(0xFFFFA85A),
              ),
          ],
        ),
        if (!(hasStepsData || hasWaterData || hasSleepData || hasCaloriesData))
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'No daily metric data available for this week.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        if (hasStepsData) ...[
          const SizedBox(height: 12),
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
              axisFormatter: (v) => _formatCompact(v),
              selectedIndex: _selectedPrimaryBar,
              onTap: (i) => setState(() => _selectedPrimaryBar = i),
            ),
          ),
        ],
        if (hasWaterData) ...[
          const SizedBox(height: 12),
          _buildChartCard(
            title: 'Water Trend (7 Days)',
            child: _buildLineChart(
              weekDates: weekDates,
              values: water,
              color: const Color(0xFF4BE4C7),
              yAxisTitle: 'Liters',
              formatYAxis: (v) => v.toStringAsFixed(1),
            ),
          ),
        ],
        if (hasSleepData) ...[
          const SizedBox(height: 12),
          _buildChartCard(
            title: 'Sleep Trend (7 Days)',
            child: _buildLineChart(
              weekDates: weekDates,
              values: sleep,
              color: const Color(0xFF8F9DFF),
              yAxisTitle: 'Hours',
              formatYAxis: (v) => v.toStringAsFixed(1),
            ),
          ),
        ],
        if (hasCaloriesData) ...[
          const SizedBox(height: 12),
          _buildChartCard(
            title: 'Calories Trend (7 Days)',
            child: _buildLineChart(
              weekDates: weekDates,
              values: calories,
              color: const Color(0xFFFFA85A),
              yAxisTitle: 'kcal',
              formatYAxis: (v) => _formatCompact(v),
            ),
          ),
        ],
      ],
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

    final plannedTrainingDays = _toInt(training['plan_days_per_week']) > 0
        ? _toInt(training['plan_days_per_week'])
        : plannedDaysFromHistory;
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
              value: totalExercisesThisWeek > 0
                  ? '${weeklyAdherencePct.toStringAsFixed(0)}% ($completedExercisesThisWeek/$totalExercisesThisWeek exercises)'
                  : '${weeklyAdherencePct.toStringAsFixed(0)}% (-)',
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
        _buildChartCard(
          title: 'Exercises Done',
          subtitle: 'From training history logs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selectedWeekHistory.length} training day(s), $completedExercisesCount completed exercise(s)',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openAllExercisesDonePage(selectedWeekHistory),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('View all exercises done'),
                ),
              ),
            ],
          ),
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
                  style: TextStyle(color: Colors.white70),
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
                  style: TextStyle(color: Colors.white70),
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
                  style: TextStyle(color: Colors.white70),
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

    final whoopLinked = whoop['linked'] == true;
    final fitbitLinked = fitbit['linked'] == true;
    final whoopAvailable =
        whoop['has_metrics'] == true || whoopRows.isNotEmpty || whoopLinked;
    final fitbitAvailable =
        fitbit['has_metrics'] == true || fitbitRows.isNotEmpty || fitbitLinked;
    final hasWhoop = whoopAvailable;
    final hasFitbit = fitbitAvailable;
    final canSwitchProvider = hasWhoop && hasFitbit;
    final effectiveProvider = canSwitchProvider
        ? _selectedWearableProvider
        : (hasWhoop ? _wearableWhoop : _wearableFitbit);
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
            title: 'Fitbit Readiness (7 Days)',
            byDate: fitbitByDate,
            key: 'readiness_score',
            gradient: const [Color(0xFF3BC7FF), Color(0xFF7C8BFF)],
            selectedGradient: const [Color(0xFF6FDCFF), Color(0xFFA1ADFF)],
            formatValue: (v) => v.toStringAsFixed(0),
          ),
          metricCard(
            title: 'Fitbit Stress Score (7 Days)',
            byDate: fitbitByDate,
            key: 'stress_management_score',
            gradient: const [Color(0xFFFFA65A), Color(0xFFFF6E7B)],
            selectedGradient: const [Color(0xFFFFC07F), Color(0xFFFF8A94)],
            formatValue: (v) => v.toStringAsFixed(0),
          ),
        ],
      ].whereType<Widget>(),
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (whoopLinked || fitbitLinked)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (whoopLinked)
                _buildSummaryPill(
                  label: 'Whoop',
                  value: 'Connected',
                  accent: const Color(0xFF4BE4C7),
                ),
              if (fitbitLinked)
                _buildSummaryPill(
                  label: 'Fitbit',
                  value: 'Connected',
                  accent: const Color(0xFF4BE4C7),
                ),
            ],
          ),
        if (canSwitchProvider) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: effectiveProvider == _wearableWhoop,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _selectedWearableProvider = _wearableWhoop;
                        _selectedPrimaryBar = null;
                      });
                    },
                    label: const Center(child: Text('Whoop')),
                    labelStyle: TextStyle(
                      color: effectiveProvider == _wearableWhoop
                          ? Colors.white
                          : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.accent.withValues(alpha: 0.34),
                    backgroundColor: Colors.white.withValues(alpha: 0.02),
                    side: BorderSide(
                      color: effectiveProvider == _wearableWhoop
                          ? AppColors.accent
                          : Colors.white24,
                    ),
                    showCheckmark: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    selected: effectiveProvider == _wearableFitbit,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _selectedWearableProvider = _wearableFitbit;
                        _selectedPrimaryBar = null;
                      });
                    },
                    label: const Center(child: Text('Fitbit')),
                    labelStyle: TextStyle(
                      color: effectiveProvider == _wearableFitbit
                          ? Colors.white
                          : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: AppColors.accent.withValues(alpha: 0.34),
                    backgroundColor: Colors.white.withValues(alpha: 0.02),
                    side: BorderSide(
                      color: effectiveProvider == _wearableFitbit
                          ? AppColors.accent
                          : Colors.white24,
                    ),
                    showCheckmark: false,
                  ),
                ),
              ],
            ),
          ),
        ] else if (whoopLinked || fitbitLinked)
          const SizedBox(height: 12),
        if (chartCards.isEmpty)
          const Text(
            'No wearable metrics available for this week.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ...List<Widget>.generate(chartCards.length, (index) {
            if (index == 0) return chartCards[index];
            return Column(
              children: [const SizedBox(height: 12), chartCards[index]],
            );
          }),
      ],
    );
  }

  void _openAllExercisesDonePage(List<Map<String, dynamic>> weekEntries) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            title: const Text('All Exercises Done'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [_buildSelectedWeekExercisesContent(weekEntries)],
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
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_exerciseHistoryError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _exerciseHistoryError!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadExerciseHistory,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (weekEntries.isEmpty) {
      return const Text(
        'No exercises logged.',
        style: TextStyle(color: Colors.white70),
      );
    }
    return Column(
      children: weekEntries.map(_buildWeekExerciseDayBlock).toList(),
    );
  }

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
    final title = isWater
        ? 'Daily Metrics Details'
        : (isTraining ? 'Training & Cardio Details' : 'Wearables Details');

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(backgroundColor: AppColors.black, title: Text(title)),
      body: Column(
        children: [
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
