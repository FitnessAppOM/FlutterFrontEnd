import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/simple_line_chart.dart';
import 'expert_weekly_metrics_detail_page.dart';

class ExpertClientAnalyticsPage extends StatefulWidget {
  const ExpertClientAnalyticsPage({
    super.key,
    required this.client,
    required this.reviews,
  });

  final ProgressionClient client;
  final List<ProgressionReview> reviews;

  @override
  State<ExpertClientAnalyticsPage> createState() =>
      _ExpertClientAnalyticsPageState();
}

class _ExpertClientAnalyticsPageState extends State<ExpertClientAnalyticsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};
  List<Map<String, dynamic>> _trainingHistoryEntries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ProgressionReviewService.fetchClientAnalytics(
        widget.client.userId,
      );
      List<Map<String, dynamic>> history = const [];
      try {
        history = await ProgressionReviewService.fetchClientTrainingHistory(
          clientUserId: widget.client.userId,
          limitDays: 540,
        );
      } catch (_) {
        history = const [];
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _trainingHistoryEntries = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _normalizeError(e);
        _loading = false;
      });
    }
  }

  String _normalizeError(Object error) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('forbidden') || lower.contains('403')) {
      return 'Non available';
    }
    if (raw.startsWith('Exception: ')) {
      final clean = raw.substring('Exception: '.length).trim();
      if (clean.isNotEmpty) return clean;
    }
    return raw.isEmpty ? 'Non available' : raw;
  }

  String _formatIsoDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(raw.trim());
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
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

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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

  String _formatWeight(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return '-';
    final rounded = weightKg.roundToDouble();
    if ((weightKg - rounded).abs() < 0.001) {
      return '${rounded.toInt()} kg';
    }
    return '${weightKg.toStringAsFixed(1)} kg';
  }

  String _currentClientName() {
    final client = _map(_data['client']);
    final raw =
        (client['name'] ??
                widget.client.name ??
                'Client #${widget.client.userId}')
            .toString()
            .trim();
    return raw.isEmpty ? 'Client #${widget.client.userId}' : raw;
  }

  Future<void> _openWeeklyDetail(ExpertWeeklyMetricsDetailType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertWeeklyMetricsDetailPage(
          type: type,
          clientUserId: widget.client.userId,
          clientName: _currentClientName(),
          analyticsData: _data,
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final client = _map(_data['client']);
    final name =
        (client['name'] ??
                widget.client.name ??
                'Client #${widget.client.userId}')
            .toString();

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
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'User ID: ${widget.client.userId}',
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    final activity = _map(_data['activity']);
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
          const Text(
            'Activity Snapshot',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Last action',
            value: _formatIsoDate(activity['last_action_date']?.toString()),
          ),
          _InfoRow(
            label: 'Last training',
            value: _formatIsoDate(activity['last_training_date']?.toString()),
          ),
          _InfoRow(
            label: 'Last cardio',
            value: _formatIsoDate(activity['last_cardio_date']?.toString()),
          ),
          _InfoRow(
            label: 'Last habit check',
            value: _formatIsoDate(activity['last_habit_date']?.toString()),
          ),
          _InfoRow(
            label: 'Inactive days',
            value: activity['inactive_days']?.toString() ?? '-',
          ),
          _InfoRow(
            label: 'Status',
            value: activity['activity_status']?.toString() ?? '-',
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTrendCard() {
    final weight = _map(_data['weight']);
    final historyRaw = _mapList(weight['history']);
    final currentWeight = _toNullableDouble(weight['current_weight_kg']);
    final entries =
        historyRaw
            .map((row) {
              final value = _toNullableDouble(row['weight_kg']);
              final date = _dateOnly(row['recorded_at']?.toString());
              if (value == null || date == null) return null;
              return {'weight_kg': value, 'date': date};
            })
            .whereType<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          );

    final hasTrend = entries.length >= 2;
    final startWeight = hasTrend ? entries.first['weight_kg'] as double : null;
    final latestWeight = hasTrend ? entries.last['weight_kg'] as double : null;
    final delta = (startWeight != null && latestWeight != null)
        ? (latestWeight - startWeight)
        : null;
    final deltaLabel = delta == null
        ? '-'
        : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg';

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
          const Text(
            'Weight',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(label: 'Current', value: _formatWeight(currentWeight)),
          _InfoRow(
            label: 'Changes tracked',
            value: entries.isEmpty ? '0' : '${entries.length}',
          ),
          if (!hasTrend)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Not enough weight history yet.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 140,
              child: SimpleLineChart(
                values: entries
                    .map((entry) => entry['weight_kg'] as double)
                    .toList(),
                color: const Color(0xFF5FD8FF),
                height: 140,
                showPoints: true,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Range',
              value:
                  '${DateFormat('dd MMM yyyy').format(entries.first['date'] as DateTime)} \u2192 ${DateFormat('dd MMM yyyy').format(entries.last['date'] as DateTime)}',
            ),
            _InfoRow(label: 'Net change', value: deltaLabel),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyMetricsCard() {
    final dailyMetrics = _map(_data['daily_metrics']);
    final rows = _mapList(dailyMetrics['last_7_days']);
    final totalWater = rows.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['water_liters']),
    );
    final totalSteps = rows.fold<int>(
      0,
      (sum, row) => sum + _toInt(row['steps']),
    );
    final waterDays = rows
        .where((row) => _toDouble(row['water_liters']) > 0)
        .length;
    final stepsDays = rows.where((row) => _toInt(row['steps']) > 0).length;
    final avgSteps = stepsDays > 0 ? (totalSteps / stepsDays).round() : 0;
    final totalSleepHours = rows.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['sleep_hours']),
    );
    final totalCalories = rows.fold<int>(
      0,
      (sum, row) => sum + _toInt(row['calories']),
    );
    final sleepDays = rows.where((row) => row['sleep_hours'] != null).length;
    final caloriesDays = rows.where((row) => row['calories'] != null).length;
    final avgSleepHours = sleepDays > 0 ? (totalSleepHours / sleepDays) : 0;
    final avgCalories = caloriesDays > 0
        ? (totalCalories / caloriesDays).round()
        : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            _openWeeklyDetail(ExpertWeeklyMetricsDetailType.waterSteps),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Daily Metrics (Last 7 Days)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Text(
                  'No daily metrics available.',
                  style: TextStyle(color: Colors.white70),
                )
              else ...[
                _InfoRow(
                  label: 'Water logged',
                  value: '${totalWater.toStringAsFixed(1)} L ($waterDays days)',
                ),
                _InfoRow(label: 'Steps total', value: '$totalSteps'),
                _InfoRow(label: 'Avg steps/day', value: '$avgSteps'),
                _InfoRow(
                  label: 'Sleep (avg/day)',
                  value: sleepDays > 0
                      ? '${avgSleepHours.toStringAsFixed(1)} h'
                      : '-',
                ),
                _InfoRow(
                  label: 'Calories (avg/day)',
                  value: caloriesDays > 0 ? '$avgCalories kcal' : '-',
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap to open weekly charts',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainingCard() {
    final training = _map(_data['training']);
    final selectedWeekStart =
        _dateOnly(training['week_start']?.toString()) ??
        _dateOnly(training['last_7_start']?.toString());
    final selectedWeekKey = selectedWeekStart != null
        ? _dateKey(selectedWeekStart)
        : null;
    final selectedWeekHistory = selectedWeekKey == null
        ? const <Map<String, dynamic>>[]
        : _trainingHistoryEntries.where((entry) {
            final weekStart = _dateOnly(entry['week_start']?.toString());
            if (weekStart == null) return false;
            return _dateKey(weekStart) == selectedWeekKey;
          }).toList();

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

    final completedTrainingDayByKey = <String, bool>{};
    final startedTrainingDayByKey = <String, bool>{};
    int plannedDaysFromHistory = 0;
    for (final dayEntry in selectedWeekHistory) {
      final completed = _toInt(dayEntry['completed_count']);
      final total = _toInt(dayEntry['total_count']);
      final planDays = _toInt(dayEntry['plan_days_per_week']);
      if (planDays > plannedDaysFromHistory) {
        plannedDaysFromHistory = planDays;
      }
      final trainingDayKey = normalizedTrainingDayKey(dayEntry);
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
    final displayDaysInProgress = startedTrainingDays;
    final displayDaysDone = cappedCompletedTrainingDays;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            _openWeeklyDetail(ExpertWeeklyMetricsDetailType.trainingCardio),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Training & Cardio (This Week)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Days in progress',
                value: '$displayDaysInProgress',
              ),
              _InfoRow(label: 'Days done', value: '$displayDaysDone'),
              _InfoRow(
                label: 'Training exercises done',
                value: '${_toInt(training['training_items_done'])}',
              ),
              _InfoRow(
                label: 'Cardio sessions done',
                value: '${_toInt(training['cardio_sessions_done'])}',
              ),
              _InfoRow(
                label: 'Cardio distance',
                value:
                    '${_toDouble(training['cardio_distance_km']).toStringAsFixed(1)} km',
              ),
              _InfoRow(
                label: 'Cardio steps',
                value: '${_toInt(training['cardio_steps'])}',
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to open weekly charts',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWearablesCard() {
    final wearables = _map(_data['wearables']);
    final whoop = _map(wearables['whoop']);
    final fitbit = _map(wearables['fitbit']);
    final whoopLinked = whoop['linked'] == true;
    final fitbitLinked = fitbit['linked'] == true;
    final whoopHasData = whoop['has_metrics'] == true;
    final fitbitHasData = fitbit['has_metrics'] == true;
    final hasAnyWearable =
        whoopLinked || whoopHasData || fitbitLinked || fitbitHasData;

    String wearableLabel({
      required bool linked,
      required bool hasData,
      required String? status,
    }) {
      final normalized = (status ?? '').trim().toLowerCase();
      if (linked ||
          hasData ||
          normalized == 'connected' ||
          normalized == 'data_only') {
        return 'Connected';
      }
      return 'Not connected';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasAnyWearable
            ? () => _openWeeklyDetail(ExpertWeeklyMetricsDetailType.wearables)
            : null,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Wearables',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (hasAnyWearable)
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Whoop',
                value: wearableLabel(
                  linked: whoopLinked,
                  hasData: whoopHasData,
                  status: whoop['status']?.toString(),
                ),
              ),
              _InfoRow(
                label: 'Fitbit',
                value: wearableLabel(
                  linked: fitbitLinked,
                  hasData: fitbitHasData,
                  status: fitbit['status']?.toString(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasAnyWearable
                    ? 'Tap to open weekly wearable charts'
                    : 'No wearable connection detected.',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          _buildHeaderCard(),
          const SizedBox(height: 12),
          _buildActivityCard(),
          const SizedBox(height: 12),
          _buildWeightTrendCard(),
          const SizedBox(height: 12),
          _buildDailyMetricsCard(),
          const SizedBox(height: 12),
          _buildTrainingCard(),
          const SizedBox(height: 12),
          _buildWearablesCard(),
          const SizedBox(height: 20),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Client Analytics'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          body,
          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white60)),
          ),
          const SizedBox(width: 8),
          Flexible(
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
      ),
    );
  }
}
