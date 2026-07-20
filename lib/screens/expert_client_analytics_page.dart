import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import '../TaqaUI/components/taqa_expert_dashboard_ui.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../services/coach/progression_review_service.dart';
import '../widgets/charts/simple_line_chart.dart';
import 'expert_training_plan_review_page.dart';
import 'expert_weekly_metrics_detail_page.dart';

class ExpertClientAnalyticsPage extends StatefulWidget {
  const ExpertClientAnalyticsPage({
    super.key,
    required this.client,
    required this.reviews,
    this.onTrainingPlanVerified,
  });

  final ProgressionClient client;
  final List<ProgressionReview> reviews;
  final VoidCallback? onTrainingPlanVerified;

  @override
  State<ExpertClientAnalyticsPage> createState() =>
      _ExpertClientAnalyticsPageState();
}

class _ExpertClientAnalyticsPageState extends State<ExpertClientAnalyticsPage> {
  static final Map<int, Map<String, dynamic>> _dataCache =
      <int, Map<String, dynamic>>{};
  static final Map<int, List<Map<String, dynamic>>> _trainingHistoryCache =
      <int, List<Map<String, dynamic>>>{};
  static final Map<int, Map<String, dynamic>> _activeProgramCache =
      <int, Map<String, dynamic>>{};
  static final Map<int, String?> _trainingPlanErrorCache = <int, String?>{};

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};
  List<Map<String, dynamic>> _trainingHistoryEntries = const [];
  Map<String, dynamic> _activeProgram = const {};
  String? _trainingPlanError;

  @override
  void initState() {
    super.initState();
    final cachedData = _dataCache[widget.client.userId];
    if (cachedData != null) {
      _data = cachedData;
      _trainingHistoryEntries =
          _trainingHistoryCache[widget.client.userId] ?? const [];
      _activeProgram = _activeProgramCache[widget.client.userId] ?? const {};
      _trainingPlanError = _trainingPlanErrorCache[widget.client.userId];
      _loading = false;
      _load(showLoading: false);
    } else {
      _load();
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _loading = true;
        _error = null;
        _activeProgram = const {};
        _trainingPlanError = null;
      });
    }
    try {
      final data = await ProgressionReviewService.fetchClientAnalytics(
        widget.client.userId,
      );
      List<Map<String, dynamic>> history = const [];
      Map<String, dynamic> activeProgram = const {};
      String? trainingPlanError;
      try {
        history = await ProgressionReviewService.fetchClientTrainingHistory(
          clientUserId: widget.client.userId,
          limitDays: 540,
        );
      } catch (_) {
        history = const [];
      }
      try {
        activeProgram =
            await ProgressionReviewService.fetchClientActiveTrainingProgram(
              widget.client.userId,
            );
      } catch (e) {
        final normalized = _normalizeError(e);
        if (normalized.toLowerCase().contains(
              'failed to load client training program',
            ) ||
            normalized.toLowerCase().contains('no program found') ||
            normalized.toLowerCase().contains('404')) {
          trainingPlanError = 'No active training plan yet.';
        } else {
          trainingPlanError = normalized;
        }
        activeProgram = const {};
      }
      _dataCache[widget.client.userId] = data;
      _trainingHistoryCache[widget.client.userId] = history;
      _activeProgramCache[widget.client.userId] = activeProgram;
      _trainingPlanErrorCache[widget.client.userId] = trainingPlanError;
      if (!mounted) return;
      setState(() {
        _data = data;
        _trainingHistoryEntries = history;
        _activeProgram = activeProgram;
        _trainingPlanError = trainingPlanError;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // A silent background refresh failing shouldn't blow away content
      // already showing from cache — only surface the error on a real
      // (user-visible) load.
      if (!showLoading) {
        setState(() => _loading = false);
        return;
      }
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

  String _activePlanSource() {
    final source = (_activeProgram['plan_source'] ?? '').toString().trim();
    if (source == 'ai_generated' || source == 'expert_created') return source;
    final createdBy = (_activeProgram['created_by'] ?? '').toString().trim();
    return createdBy == 'expert' ? 'expert_created' : 'ai_generated';
  }

  bool _activePlanVerified() {
    final raw = _activeProgram['expert_verified'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = (raw ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  bool _hasUncheckedTrainingPlan() {
    if (_activeProgram.isNotEmpty) {
      return _activePlanSource() == 'ai_generated' && !_activePlanVerified();
    }
    return widget.client.hasUncheckedTrainingPlan;
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
          clientAvatarUrl: widget.client.avatarUrl,
          clientActivityStatus: widget.client.activityStatus,
          analyticsData: _data,
          activeProgram: _activeProgram,
          trainingPlanError: _trainingPlanError,
          onTrainingPlanVerified: widget.onTrainingPlanVerified,
        ),
      ),
    );
    if (!mounted || type != ExpertWeeklyMetricsDetailType.trainingCardio) {
      return;
    }
    try {
      final latestProgram =
          await ProgressionReviewService.fetchClientActiveTrainingProgram(
            widget.client.userId,
          );
      if (!mounted) return;
      setState(() {
        _activeProgram = latestProgram;
        _trainingPlanError = null;
      });
    } catch (_) {}
  }

  Future<void> _openTrainingPlanEditor() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ExpertTrainingPlanReviewPage(
          clientUserId: widget.client.userId,
          clientName: _currentClientName(),
          clientAvatarUrl: widget.client.avatarUrl,
          clientActivityStatus: widget.client.activityStatus,
          activeProgram: _activeProgram,
          trainingPlanError: _trainingPlanError,
        ),
      ),
    );
    if (!mounted || result == null) return;

    final updatedProgram = result['activeProgram'];
    if (updatedProgram is Map) {
      setState(() {
        _activeProgram = Map<String, dynamic>.from(updatedProgram);
        _trainingPlanError = null;
      });
    }
    if (result['didCheck'] == true) {
      widget.onTrainingPlanVerified?.call();
    }
  }

  Widget _buildHeaderCard() {
    final client = _map(_data['client']);
    final name =
        (client['name'] ??
                widget.client.name ??
                'Client #${widget.client.userId}')
            .toString();

    return TaqaExpertClientCard(
      name: name,
      avatarUrl: widget.client.avatarUrl,
      status: widget.client.activityStatus,
      subtitle: 'User ID: ${widget.client.userId}',
      alerts: const [],
    );
  }

  Widget _buildActivityCard() {
    final activity = _map(_data['activity']);
    return TaqaClientDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TaqaClientDashboardTitleText('Activity Snapshot'),
          SizedBox(height: TaqaUiScale.h(8)),
          TaqaClientDashboardInfoRow(
            label: 'Last action',
            value: _formatIsoDate(activity['last_action_date']?.toString()),
          ),
          TaqaClientDashboardInfoRow(
            label: 'Last training',
            value: _formatIsoDate(activity['last_training_date']?.toString()),
          ),
          TaqaClientDashboardInfoRow(
            label: 'Last cardio',
            value: _formatIsoDate(activity['last_cardio_date']?.toString()),
          ),
          TaqaClientDashboardInfoRow(
            label: 'Last habit check',
            value: _formatIsoDate(activity['last_habit_date']?.toString()),
          ),
          TaqaClientDashboardInfoRow(
            label: 'Inactive days',
            value: activity['inactive_days']?.toString() ?? '-',
          ),
          TaqaClientDashboardInfoRow(
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

    return TaqaClientDashboardNavigationCard(
      title: 'Weight',
      description: 'Track the client’s current weight and progress.',
      onTap: null,
      showChevron: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaqaClientDashboardInfoRow(
            label: 'Current',
            value: _formatWeight(currentWeight),
          ),
          TaqaClientDashboardInfoRow(
            label: 'Changes tracked',
            value: entries.isEmpty ? '0' : '${entries.length}',
          ),
          if (!hasTrend)
            Padding(
              padding: EdgeInsets.only(top: TaqaUiScale.h(6)),
              child: TaqaClientDashboardBodyText(
                'Not enough weight history yet.',
                color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
              ),
            )
          else ...[
            SizedBox(height: TaqaUiScale.h(6)),
            SizedBox(
              height: TaqaUiScale.h(140),
              child: SimpleLineChart(
                values: entries
                    .map((entry) => entry['weight_kg'] as double)
                    .toList(),
                color: const Color(0xFF5FD8FF),
                height: TaqaUiScale.h(140),
                showPoints: true,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            TaqaClientDashboardInfoRow(
              label: 'Range',
              value:
                  '${DateFormat('dd MMM yyyy').format(entries.first['date'] as DateTime)} \u2192 ${DateFormat('dd MMM yyyy').format(entries.last['date'] as DateTime)}',
            ),
            TaqaClientDashboardInfoRow(label: 'Net change', value: deltaLabel),
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

    return TaqaClientDashboardCard(
      onTap: () => _openWeeklyDetail(ExpertWeeklyMetricsDetailType.waterSteps),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const TaqaClientDashboardTitleText(
                  'Daily Metrics (Last 7 Days)',
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
                size: TaqaUiScale.w(20),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          if (rows.isEmpty)
            TaqaClientDashboardBodyText(
              'No daily metrics available.',
              color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
            )
          else ...[
            TaqaClientDashboardInfoRow(
              label: 'Water logged',
              value: '${totalWater.toStringAsFixed(1)} L ($waterDays days)',
            ),
            TaqaClientDashboardInfoRow(
              label: 'Steps total',
              value: '$totalSteps',
            ),
            TaqaClientDashboardInfoRow(
              label: 'Avg steps/day',
              value: '$avgSteps',
            ),
            TaqaClientDashboardInfoRow(
              label: 'Sleep (avg/day)',
              value: sleepDays > 0
                  ? '${avgSleepHours.toStringAsFixed(1)} h'
                  : '-',
            ),
            TaqaClientDashboardInfoRow(
              label: 'Calories (avg/day)',
              value: caloriesDays > 0 ? '$avgCalories kcal' : '-',
            ),
            SizedBox(height: TaqaUiScale.h(4)),
            TaqaClientDashboardBodyText(
              'Tap to open weekly charts',
              color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainingCard() {
    final training = _map(_data['training']);
    final hasUncheckedPlan = _hasUncheckedTrainingPlan();
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

    return TaqaClientDashboardCard(
      onTap: () =>
          _openWeeklyDetail(ExpertWeeklyMetricsDetailType.trainingCardio),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const TaqaClientDashboardTitleText(
                  'Training & Cardio (This Week)',
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
                size: TaqaUiScale.w(20),
              ),
            ],
          ),
          if (hasUncheckedPlan) ...[
            SizedBox(height: TaqaUiScale.h(6)),
            const TaqaClientAlertText(text: "Client's plan not checked yet."),
          ],
          SizedBox(height: TaqaUiScale.h(8)),
          TaqaClientDashboardInfoRow(
            label: 'Days in progress',
            value: '$displayDaysInProgress',
          ),
          TaqaClientDashboardInfoRow(
            label: 'Days done',
            value: '$displayDaysDone',
          ),
          TaqaClientDashboardInfoRow(
            label: 'Training exercises done',
            value: '${_toInt(training['training_items_done'])}',
          ),
          TaqaClientDashboardInfoRow(
            label: 'Cardio sessions done',
            value: '${_toInt(training['cardio_sessions_done'])}',
          ),
          TaqaClientDashboardInfoRow(
            label: 'Cardio distance',
            value:
                '${_toDouble(training['cardio_distance_km']).toStringAsFixed(1)} km',
          ),
          TaqaClientDashboardInfoRow(
            label: 'Cardio steps',
            value: '${_toInt(training['cardio_steps'])}',
          ),
          SizedBox(height: TaqaUiScale.h(4)),
          TaqaClientDashboardBodyText(
            'Tap to open weekly charts',
            color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaFilledButton(
            label: 'Edit Training Plan',
            onTap: _openTrainingPlanEditor,
          ),
        ],
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

    return TaqaClientDashboardCard(
      onTap: hasAnyWearable
          ? () => _openWeeklyDetail(ExpertWeeklyMetricsDetailType.wearables)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: const TaqaClientDashboardTitleText('Wearables')),
              if (hasAnyWearable)
                Icon(
                  Icons.chevron_right,
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
                  size: TaqaUiScale.w(20),
                ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          TaqaClientDashboardInfoRow(
            label: 'Whoop',
            value: wearableLabel(
              linked: whoopLinked,
              hasData: whoopHasData,
              status: whoop['status']?.toString(),
            ),
          ),
          TaqaClientDashboardInfoRow(
            label: 'Fitbit',
            value: wearableLabel(
              linked: fitbitLinked,
              hasData: fitbitHasData,
              status: fitbit['status']?.toString(),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(4)),
          TaqaClientDashboardBodyText(
            hasAnyWearable
                ? 'Tap to open weekly wearable charts'
                : 'No wearable connection detected.',
            color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLoadedContent = _data.isNotEmpty || _error != null;
    final body = _loading && !hasLoadedContent
        ? const Center(child: TaqaLoadingIndicator())
        : TaqaRefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TaqaUiScale.insetsLTRB(16, 12, 17, 24),
              children: [
                if (_error != null)
                  TaqaClientDashboardCard(
                    child: TaqaClientDashboardBodyText(
                      _error!,
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
                    ),
                  ),
                if (hasLoadedContent) ...[
                  if (_error != null) SizedBox(height: TaqaUiScale.h(12)),
                  _buildHeaderCard(),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _buildWeightTrendCard(),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _buildTrainingCard(),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _buildActivityCard(),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _buildDailyMetricsCard(),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _buildWearablesCard(),
                ],
              ],
            ),
          );

    return Scaffold(
      backgroundColor: TaqaUiColors.lightGray,
      appBar: const TaqaPageAppBar(title: 'Client Analytics'),
      body: body,
    );
  }
}
