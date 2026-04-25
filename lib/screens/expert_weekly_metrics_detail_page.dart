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
  int? _selectedPrimaryBar;
  int _weekOffset = 0;
  bool _loadingWeek = false;
  String? _weekError;
  bool _loadingExerciseHistory = false;
  String? _exerciseHistoryError;
  List<Map<String, dynamic>> _exerciseHistoryEntries = const [];
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
      unawaited(_changeWeek(1));
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
    for (final date in weekDates) {
      final row = byDate[_dateKey(date)];
      steps.add(_toInt(row?['steps']).toDouble());
      water.add(_toDouble(row?['water_liters']));
    }

    final totalSteps = steps.fold<double>(0, (sum, value) => sum + value);
    final totalWater = water.fold<double>(0, (sum, value) => sum + value);
    final nonZeroStepDays = steps.where((v) => v > 0).length;
    final avgSteps = nonZeroStepDays == 0
        ? 0.0
        : (totalSteps / nonZeroStepDays);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSummaryPill(
              label: 'Weekly Steps',
              value: _formatCompact(totalSteps),
              accent: const Color(0xFF63D5FF),
            ),
            _buildSummaryPill(
              label: 'Average Steps/Active Day',
              value: _formatCompact(avgSteps),
              accent: const Color(0xFF9DA6FF),
            ),
            _buildSummaryPill(
              label: 'Weekly Water',
              value: '${totalWater.toStringAsFixed(1)} L',
              accent: const Color(0xFF4BE4C7),
            ),
          ],
        ),
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
    );
  }

  Widget _buildTrainingCardioContent() {
    final training = _map(_analyticsData['training']);
    final weekDates = _weekDates(
      startRaw: training['last_7_start']?.toString(),
      endRaw: training['today']?.toString(),
    );
    final trainingRows = _mapList(training['recent_training_days']);
    final cardioRows = _mapList(training['recent_cardio_sessions']);

    final trainingItemsByDate = <String, int>{};
    for (final row in trainingRows) {
      final date = _dateOnly(row['entry_date']?.toString());
      if (date == null) continue;
      trainingItemsByDate[_dateKey(date)] = _toInt(row['completed_items']);
    }

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

    final trainingItems = <double>[];
    final cardioSteps = <double>[];
    final cardioDistance = <double>[];
    for (final date in weekDates) {
      final key = _dateKey(date);
      trainingItems.add((trainingItemsByDate[key] ?? 0).toDouble());
      cardioSteps.add((cardioStepsByDate[key] ?? 0).toDouble());
      cardioDistance.add(cardioDistanceByDate[key] ?? 0);
    }

    final selectedWeekHistory = _selectedWeekHistoryEntries();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSummaryPill(
              label: 'Training Days',
              value: '${_toInt(training['strength_days_done'])}',
              accent: const Color(0xFF5FD8FF),
            ),
            _buildSummaryPill(
              label: 'Training Items',
              value: '${_toInt(training['training_items_done'])}',
              accent: const Color(0xFFA4AEFF),
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
          title: 'Exercises',
          subtitle: 'From training history logs',
          child: _buildSelectedWeekExercisesContent(selectedWeekHistory),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Training Items per Day',
          subtitle: _selectedPrimaryBar == null
              ? 'Tap a bar to inspect a day.'
              : '${_dayDetail(weekDates[_selectedPrimaryBar!])}: ${_formatCompact(trainingItems[_selectedPrimaryBar!])} completed items',
          child: _buildBarChart(
            weekDates: weekDates,
            values: trainingItems,
            gradient: const [Color(0xFF35B6FF), Color(0xFF9B8CFF)],
            selectedGradient: const [Color(0xFF5FD8FF), Color(0xFFBAAEFF)],
            axisFormatter: (v) => _formatCompact(v),
            selectedIndex: _selectedPrimaryBar,
            onTap: (i) => setState(() => _selectedPrimaryBar = i),
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

    final whoopConnected =
        whoop['linked'] == true || whoop['has_metrics'] == true;
    final fitbitConnected =
        fitbit['linked'] == true || fitbit['has_metrics'] == true;
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
          formatValue: (v) => '${v.toStringAsFixed(1)} h',
        ),
        metricCard(
          title: 'Fitbit Steps (7 Days)',
          byDate: fitbitByDate,
          key: 'steps',
          gradient: const [Color(0xFF3CB6FF), Color(0xFF8B85FF)],
          selectedGradient: const [Color(0xFF65CBFF), Color(0xFFA8A2FF)],
          formatValue: (v) => _formatCompact(v),
        ),
        metricCard(
          title: 'Fitbit Calories Out (7 Days)',
          byDate: fitbitByDate,
          key: 'calories_out',
          gradient: const [Color(0xFFFF9B5C), Color(0xFFFF6E7B)],
          selectedGradient: const [Color(0xFFFFB07D), Color(0xFFFF929C)],
          formatValue: (v) => _formatCompact(v),
        ),
        metricCard(
          title: 'Fitbit Sleep (Hours)',
          byDate: fitbitByDate,
          key: 'sleep_minutes_asleep',
          multiplier: 1 / 60,
          gradient: const [Color(0xFF4B8EFF), Color(0xFF4BE4C7)],
          selectedGradient: const [Color(0xFF6AA2FF), Color(0xFF75EDD6)],
          formatValue: (v) => '${v.toStringAsFixed(1)} h',
        ),
      ].whereType<Widget>(),
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSummaryPill(
              label: 'Whoop',
              value: whoopConnected ? 'Connected' : 'Not connected',
              accent: whoopConnected
                  ? const Color(0xFF4BE4C7)
                  : Colors.orangeAccent,
            ),
            _buildSummaryPill(
              label: 'Whoop data days',
              value: '${whoopRows.length}/7',
              accent: const Color(0xFF63D5FF),
            ),
            _buildSummaryPill(
              label: 'Fitbit',
              value: fitbitConnected ? 'Connected' : 'Not connected',
              accent: fitbitConnected
                  ? const Color(0xFF4BE4C7)
                  : Colors.orangeAccent,
            ),
            _buildSummaryPill(
              label: 'Fitbit data days',
              value: '${fitbitRows.length}/7',
              accent: const Color(0xFFA4AEFF),
            ),
          ],
        ),
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
    final completedCount = _toInt(entry['completed_count']);
    final totalCount = _toInt(entry['total_count']);
    final exercises = _mapList(entry['completed_exercises']);

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
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount/$totalCount completed',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
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
                  child: Row(
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

  @override
  Widget build(BuildContext context) {
    final isWater = widget.type == ExpertWeeklyMetricsDetailType.waterSteps;
    final isTraining =
        widget.type == ExpertWeeklyMetricsDetailType.trainingCardio;
    final title = isWater
        ? 'Water & Steps Details'
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
