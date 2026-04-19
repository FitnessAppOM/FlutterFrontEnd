import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../widgets/charts/ranged_bar_chart.dart';
import '../widgets/charts/simple_line_chart.dart';

enum ExpertWeeklyMetricsDetailType { waterSteps, trainingCardio }

class ExpertWeeklyMetricsDetailPage extends StatefulWidget {
  const ExpertWeeklyMetricsDetailPage({
    super.key,
    required this.type,
    required this.clientName,
    required this.analyticsData,
  });

  final ExpertWeeklyMetricsDetailType type;
  final String clientName;
  final Map<String, dynamic> analyticsData;

  @override
  State<ExpertWeeklyMetricsDetailPage> createState() =>
      _ExpertWeeklyMetricsDetailPageState();
}

class _ExpertWeeklyMetricsDetailPageState
    extends State<ExpertWeeklyMetricsDetailPage> {
  int? _selectedPrimaryBar;
  int? _selectedSecondaryBar;

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
    final daily = _map(widget.analyticsData['daily_metrics']);
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
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Daily Breakdown',
          child: Column(
            children: List<Widget>.generate(weekDates.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == weekDates.length - 1 ? 0 : 6,
                ),
                child: _DetailRow(
                  label: _dayDetail(weekDates[i]),
                  value:
                      '${water[i].toStringAsFixed(1)} L  •  ${_formatCompact(steps[i])} steps',
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingCardioContent() {
    final training = _map(widget.analyticsData['training']);
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
    final cardioSessionsByDate = <String, int>{};
    for (final row in cardioRows) {
      final date = _dateOnly(row['entry_date']?.toString());
      if (date == null) continue;
      final key = _dateKey(date);
      cardioStepsByDate[key] =
          (cardioStepsByDate[key] ?? 0) + _toInt(row['steps']);
      cardioDistanceByDate[key] =
          (cardioDistanceByDate[key] ?? 0) + _toDouble(row['distance_km']);
      cardioSessionsByDate[key] = (cardioSessionsByDate[key] ?? 0) + 1;
    }

    final trainingItems = <double>[];
    final cardioSteps = <double>[];
    final cardioDistance = <double>[];
    final cardioSessions = <double>[];
    for (final date in weekDates) {
      final key = _dateKey(date);
      trainingItems.add((trainingItemsByDate[key] ?? 0).toDouble());
      cardioSteps.add((cardioStepsByDate[key] ?? 0).toDouble());
      cardioDistance.add(cardioDistanceByDate[key] ?? 0);
      cardioSessions.add((cardioSessionsByDate[key] ?? 0).toDouble());
    }

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
          title: 'Cardio Distance per Day',
          child: _buildLineChart(
            weekDates: weekDates,
            values: cardioDistance,
            color: const Color(0xFFF7B267),
            yAxisTitle: 'KM',
            formatYAxis: (v) => v.toStringAsFixed(1),
          ),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Cardio Steps per Day',
          subtitle: _selectedSecondaryBar == null
              ? 'Tap a bar to inspect a day.'
              : '${_dayDetail(weekDates[_selectedSecondaryBar!])}: ${_formatCompact(cardioSteps[_selectedSecondaryBar!])} steps',
          child: _buildBarChart(
            weekDates: weekDates,
            values: cardioSteps,
            gradient: const [Color(0xFF4BE4C7), Color(0xFF73C2FF)],
            selectedGradient: const [Color(0xFF67F0D5), Color(0xFF9BD2FF)],
            axisFormatter: (v) => _formatCompact(v),
            selectedIndex: _selectedSecondaryBar,
            onTap: (i) => setState(() => _selectedSecondaryBar = i),
          ),
        ),
        const SizedBox(height: 12),
        _buildChartCard(
          title: 'Weekly Daily Breakdown',
          child: Column(
            children: List<Widget>.generate(weekDates.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == weekDates.length - 1 ? 0 : 6,
                ),
                child: _DetailRow(
                  label: _dayDetail(weekDates[i]),
                  value:
                      '${_formatCompact(trainingItems[i])} items  •  ${cardioSessions[i].toInt()} sessions  •  ${cardioDistance[i].toStringAsFixed(1)} km  •  ${_formatCompact(cardioSteps[i])} steps',
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWater = widget.type == ExpertWeeklyMetricsDetailType.waterSteps;
    final title = isWater
        ? 'Water & Steps Details'
        : 'Training & Cardio Details';

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
          Expanded(
            child: isWater
                ? _buildWaterStepsContent()
                : _buildTrainingCardioContent(),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white60)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
