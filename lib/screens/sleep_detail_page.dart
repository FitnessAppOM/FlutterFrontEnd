import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/account_storage.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../services/health/sleep_service.dart';
import '../services/whoop/whoop_sleep_service.dart';
import '../services/whoop/whoop_widget_data_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/charts/ranged_bar_chart.dart';
import '../widgets/sleep/sleep_metric_tile.dart';
import '../widgets/sleep/sleep_progress_bar.dart';
import '../widgets/sleep/sleep_stage_ring.dart';
import '../widgets/sleep/monthly_details_button.dart';
import '../widgets/common/date_switcher.dart';

class SleepDetailPage extends StatefulWidget {
  const SleepDetailPage({super.key, this.useWhoop = false});

  final bool useWhoop;

  @override
  State<SleepDetailPage> createState() => _SleepDetailPageState();
}

class _SleepDetailPageState extends State<SleepDetailPage> {
  String _range = 'weekly';
  bool _loading = true;
  Map<DateTime, double> _daily = {};
  double? _goal;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _metricsLoading = false;
  _WhoopSleepMetrics? _whoopMetrics;
  DailyMetricsEntry? _nativeMetricsEntry;
  bool _nativeMetricsLoading = false;
  bool _nativeMetricsHasData = false;
  DateTime _metricsDate = DateTime.now();
  int _metricsReqId = 0;
  int _nativeMetricsReqId = 0;
  int? _napCount;
  double? _napHours;
  bool _metricsHasData = false;
  final Map<DateTime, _WhoopSleepMetrics?> _metricsCache = {};
  final Map<DateTime, DailyMetricsEntry?> _nativeMetricsCache = {};
  final Map<DateTime, int?> _napCountCache = {};
  final Map<DateTime, double?> _napHoursCache = {};
  final Map<DateTime, bool> _metricsHasDataCache = {};
  int? _selectedBarIndex;
  Timer? _barValueTimer;

  static const _sleepGoalKey = "dashboard_sleep_goal";
  static final Map<String, Map<DateTime, double>> _rangeDataCache = {};

  String _dayToken(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  String? _rangeCacheKey({
    required int? userId,
    required DateTime start,
    required DateTime effectiveEnd,
  }) {
    if (userId == null || userId == 0) return null;
    final source = widget.useWhoop ? "whoop" : "default";
    return "$userId|$source|$_range|${_dayToken(start)}|${_dayToken(effectiveEnd)}";
  }

  Map<DateTime, double>? _readRangeDataCache(String key) {
    final cached = _rangeDataCache[key];
    if (cached == null) return null;
    return Map<DateTime, double>.from(cached);
  }

  void _writeRangeDataCache(String key, Map<DateTime, double> data) {
    _rangeDataCache[key] = Map<DateTime, double>.from(data);
    if (_rangeDataCache.length > 96) {
      final keys = _rangeDataCache.keys.toList()..sort();
      while (_rangeDataCache.length > 96 && keys.isNotEmpty) {
        _rangeDataCache.remove(keys.removeAt(0));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.useWhoop) {
      _metricsLoading = true;
    } else {
      _nativeMetricsLoading = true;
    }
    _loadGoal();
    _loadRange();
  }

  @override
  void dispose() {
    _barValueTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _goal = sp.getDouble(_sleepGoalKey) ?? 8.0;
    });
  }

  Future<void> _editGoal() async {
    final controller = TextEditingController(
      text: (_goal ?? 8.0).toStringAsFixed(1),
    );
    final res = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            "Sleep goal",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Hours per night",
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
    if (res != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(_sleepGoalKey, res);
      if (!mounted) return;
      setState(() => _goal = res);
    }
  }

  Future<void> _loadRange({bool force = false}) async {
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end;
      switch (_range) {
        case 'monthly':
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
          break;
        case 'yearly':
          // Current calendar year only (Jan 1 -> Dec 31)
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, 12, 31);
          break;
        case 'weekly':
        default:
          final today = DateTime(now.year, now.month, now.day);
          start = today.subtract(Duration(days: today.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
      }
      final effectiveEnd = now.isBefore(end) ? now : end;
      final userId = await AccountStorage.getUserId();
      final cacheKey = _rangeCacheKey(
        userId: userId,
        start: DateTime(start.year, start.month, start.day),
        effectiveEnd: DateTime(
          effectiveEnd.year,
          effectiveEnd.month,
          effectiveEnd.day,
        ),
      );
      if (!force && cacheKey != null) {
        final cached = _readRangeDataCache(cacheKey);
        if (cached != null) {
          if (!mounted) return;
          setState(() {
            _daily = cached;
            _rangeStart = start;
            _rangeEnd = end;
            _selectedBarIndex = null;
            _loading = false;
          });
          if (widget.useWhoop) {
            await _loadWhoopMetrics();
          } else {
            await _loadNativeMetrics();
          }
          return;
        }
      }
      if (mounted) {
        setState(() => _loading = true);
      }
      Map<DateTime, double> data;
      if (widget.useWhoop) {
        data = await _loadWhoopRangeOrLatest(start: start, end: effectiveEnd);
      } else {
        if (userId == null || userId == 0) {
          if (!mounted) return;
          setState(() {
            _daily = {};
            _selectedBarIndex = null;
            _loading = false;
          });
          return;
        }

        final rangeData = await DailyMetricsApi.fetchRange(
          userId: userId,
          start: start,
          end: effectiveEnd,
        );
        data = <DateTime, double>{};
        rangeData.forEach((day, entry) {
          final key = DateTime(day.year, day.month, day.day);
          final hours = entry.sleepHours ?? 0.0;
          if (hours > 0) {
            data[key] = hours;
          }
        });

        // Apply manual overrides.
        final manual = await SleepService().getManualEntries();
        manual.forEach((day, hours) {
          if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
              !day.isAfter(
                DateTime(
                  effectiveEnd.year,
                  effectiveEnd.month,
                  effectiveEnd.day,
                ),
              )) {
            data[DateTime(day.year, day.month, day.day)] = hours;
          }
        });

        // For current day, prefer HealthKit/Health Connect if no manual override exists.
        final todayKey = DateTime(now.year, now.month, now.day);
        final inRange =
            !todayKey.isBefore(DateTime(start.year, start.month, start.day)) &&
            !todayKey.isAfter(
              DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day),
            );
        if (inRange && !manual.containsKey(todayKey)) {
          final todaySleep = await SleepService().fetchSleepForDay(todayKey);
          if (todaySleep > 0) {
            data[todayKey] = todaySleep;
          }
        }
      }
      if (cacheKey != null) {
        _writeRangeDataCache(cacheKey, data);
      }
      if (!mounted) return;
      setState(() {
        _daily = data;
        _rangeStart = start;
        _rangeEnd = end;
        _selectedBarIndex = null;
        _loading = false;
      });
      if (widget.useWhoop) {
        await _loadWhoopMetrics();
      } else {
        await _loadNativeMetrics();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daily = {};
        _selectedBarIndex = null;
        _loading = false;
      });
      if (!widget.useWhoop) {
        await _loadNativeMetrics();
      }
    }
  }

  Future<void> _loadWhoopMetrics() async {
    final requestId = ++_metricsReqId;
    final dayKey = DateTime(
      _metricsDate.year,
      _metricsDate.month,
      _metricsDate.day,
    );
    final cachedHasData = _metricsHasDataCache[dayKey];
    final cachedMetrics = _metricsCache[dayKey];
    final hasCache = cachedMetrics != null || cachedHasData != null;
    setState(() {
      if (hasCache) {
        _whoopMetrics = cachedMetrics;
        _napCount = _napCountCache[dayKey];
        _napHours = _napHoursCache[dayKey];
        _metricsHasData = cachedHasData ?? cachedMetrics != null;
        _metricsLoading = false;
      } else {
        _whoopMetrics = null;
        _napCount = null;
        _napHours = null;
        _metricsHasData = false;
        _metricsLoading = true;
      }
    });
    try {
      final now = DateTime.now();
      final isToday =
          _metricsDate.year == now.year &&
          _metricsDate.month == now.month &&
          _metricsDate.day == now.day;
      final details = isToday
          ? await WhoopSleepService().fetchSleepDayDetails(_metricsDate)
          : await WhoopSleepService().fetchSleepDayDetailsFromDb(_metricsDate);
      if (!mounted) return;
      if (requestId != _metricsReqId) return;
      final sleep = details?["sleep"];
      final metrics = sleep is Map<String, dynamic>
          ? _WhoopSleepMetrics.fromSleep(sleep)
          : null;
      final napCount = details?["nap_count"];
      final napHours = details?["nap_hours"];
      final hasData = metrics != null;
      _metricsCache[dayKey] = metrics;
      _napCountCache[dayKey] = napCount is num
          ? napCount.round()
          : int.tryParse("$napCount");
      _napHoursCache[dayKey] = napHours is num
          ? napHours.toDouble()
          : double.tryParse("$napHours");
      _metricsHasDataCache[dayKey] = hasData;
      setState(() {
        _whoopMetrics = metrics;
        _napCount = _napCountCache[dayKey];
        _napHours = _napHoursCache[dayKey];
        _metricsHasData = hasData;
        _metricsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (requestId != _metricsReqId) return;
      if (hasCache) {
        setState(() => _metricsLoading = false);
        return;
      }
      setState(() {
        _whoopMetrics = null;
        _napCount = null;
        _napHours = null;
        _metricsHasData = false;
        _metricsLoading = false;
      });
    }
  }

  bool _nativeEntryHasData(DailyMetricsEntry? entry) {
    if (entry == null) return false;
    return (entry.sleepHours ?? 0) > 0 ||
        (entry.sleepMinutesAsleep ?? 0) > 0 ||
        (entry.sleepMinutesInBed ?? 0) > 0 ||
        (entry.sleepMinutesAwake ?? 0) > 0 ||
        (entry.sleepMinutesLight ?? 0) > 0 ||
        (entry.sleepMinutesDeep ?? 0) > 0 ||
        (entry.sleepMinutesRem ?? 0) > 0;
  }

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int? _positiveInt(int? value) => (value != null && value > 0) ? value : null;

  double? _positiveDouble(double? value) =>
      (value != null && value > 0) ? value : null;

  DailyMetricsEntry? _mergeLiveSleepIntoEntry({
    required DateTime dayKey,
    required DailyMetricsEntry? entry,
    required double? liveHours,
    required SleepDayMetrics? liveMetrics,
  }) {
    final merged = DailyMetricsEntry(
      entryDate: dayKey,
      sleepHours:
          _positiveDouble(entry?.sleepHours) ?? _positiveDouble(liveHours),
      sleepMinutesAsleep:
          _positiveInt(entry?.sleepMinutesAsleep) ??
          _positiveInt(liveMetrics?.asleepMinutes),
      sleepMinutesInBed:
          _positiveInt(entry?.sleepMinutesInBed) ??
          _positiveInt(liveMetrics?.inBedMinutes),
      sleepMinutesAwake:
          _positiveInt(entry?.sleepMinutesAwake) ??
          _positiveInt(liveMetrics?.awakeMinutes),
      sleepMinutesLight:
          _positiveInt(entry?.sleepMinutesLight) ??
          _positiveInt(liveMetrics?.lightMinutes),
      sleepMinutesDeep:
          _positiveInt(entry?.sleepMinutesDeep) ??
          _positiveInt(liveMetrics?.deepMinutes),
      sleepMinutesRem:
          _positiveInt(entry?.sleepMinutesRem) ??
          _positiveInt(liveMetrics?.remMinutes),
      calories: entry?.calories,
      waterLiters: entry?.waterLiters,
      steps: entry?.steps,
    );
    return _nativeEntryHasData(merged) ? merged : entry;
  }

  Future<DailyMetricsEntry?> _resolveNativeSleepEntry({
    required DateTime dayKey,
    required DailyMetricsEntry? entry,
  }) async {
    if (_nativeEntryHasData(entry)) return entry;

    final sleep = SleepService();
    // Use strict day-based reads for every selected date (including today)
    // to avoid showing previous-day values from "last 24h".
    final liveMetrics = await sleep.fetchSleepMetricsForDay(dayKey);
    final liveHours = await sleep.fetchSleepForDay(dayKey);
    return _mergeLiveSleepIntoEntry(
      dayKey: dayKey,
      entry: entry,
      liveHours: liveHours,
      liveMetrics: liveMetrics,
    );
  }

  Future<void> _loadNativeMetrics({bool force = false}) async {
    if (widget.useWhoop) return;
    final requestId = ++_nativeMetricsReqId;
    final dayKey = _onlyDate(_metricsDate);
    final isToday = _isSameDay(dayKey, _onlyDate(DateTime.now()));
    final hasCache = _nativeMetricsCache.containsKey(dayKey);
    final canUseCache = hasCache && !force && !isToday;

    if (!mounted) return;
    setState(() {
      if (canUseCache) {
        final cached = _nativeMetricsCache[dayKey];
        _nativeMetricsEntry = cached;
        _nativeMetricsHasData = _nativeEntryHasData(cached);
        _nativeMetricsLoading = false;
      } else {
        _nativeMetricsLoading = true;
      }
    });
    if (canUseCache) return;

    final userId = await AccountStorage.getUserId();
    if (!mounted || requestId != _nativeMetricsReqId) return;
    if (userId == null || userId == 0) {
      setState(() {
        _nativeMetricsEntry = null;
        _nativeMetricsHasData = false;
        _nativeMetricsLoading = false;
      });
      return;
    }

    DailyMetricsEntry? entry;
    if (isToday) {
      // Current-day metrics should come from live HealthKit/Health Connect.
      // Skip backend fetch and ignore cached same-day rows to avoid carrying
      // forward stale values from previous-day "last 24h" reads.
      entry = null;
    } else {
      try {
        entry = await DailyMetricsApi.fetchForDate(userId, dayKey);
      } catch (_) {
        entry = _nativeMetricsCache[dayKey];
      }
    }
    if (!mounted || requestId != _nativeMetricsReqId) return;

    final resolved = await _resolveNativeSleepEntry(
      dayKey: dayKey,
      entry: entry,
    );
    if (!mounted || requestId != _nativeMetricsReqId) return;

    _nativeMetricsCache[dayKey] = resolved;
    setState(() {
      _nativeMetricsEntry = resolved;
      _nativeMetricsHasData = _nativeEntryHasData(resolved);
      _nativeMetricsLoading = false;
    });
  }

  Future<Map<DateTime, double>> _loadWhoopRangeOrLatest({
    required DateTime start,
    required DateTime end,
  }) async {
    final service = WhoopSleepService();
    final data = await service.fetchDailySleepFromDb(start: start, end: end);
    final startKey = DateTime(start.year, start.month, start.day);
    final endKey = DateTime(end.year, end.month, end.day);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final inRange = !todayKey.isBefore(startKey) && !todayKey.isAfter(endKey);
    if (inRange) {
      final userId = await AccountStorage.getUserId();
      double? todayHours;
      if (userId != null && userId != 0) {
        todayHours = WhoopWidgetDataService.cachedSleepHoursForDate(
          userId: userId,
          date: todayKey,
        );
      }
      if (todayHours == null || todayHours <= 0) {
        todayHours = await service.fetchSleepHoursForDay(todayKey);
        if (todayHours != null &&
            todayHours > 0 &&
            userId != null &&
            userId != 0) {
          WhoopWidgetDataService.cacheSleepHoursForDate(
            userId: userId,
            date: todayKey,
            sleepHours: todayHours,
          );
        }
      }
      if (todayHours != null && todayHours > 0) {
        data[todayKey] = todayHours;
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final theme = Theme.of(context);
    final bars = _buildBars(theme);

    return Scaffold(
      appBar: AppBar(
        title: Text(t("sleep_title")),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.accent,
                labelStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: "Sleep trends"),
                  Tab(text: "Sleep metrics"),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTrendsTab(t, theme, bars),
                    widget.useWhoop
                        ? _buildMetricsTab(theme)
                        : _buildNativeMetricsTab(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendsTab(
    String Function(String) t,
    ThemeData theme,
    Widget bars,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('weekly', t("range_weekly")),
            _chip('monthly', t("range_monthly")),
            _chip('yearly', t("range_yearly")),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!widget.useWhoop)
              ElevatedButton(
                onPressed: _promptManualEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(t("sleep_edit_today")),
              ),
            if (!widget.useWhoop) const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _editGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardDark,
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.7),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t(
                  "sleep_goal_btn",
                ).replaceAll("{value}", (_goal ?? 8.0).toStringAsFixed(1)),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (widget.useWhoop) ...[
              const Spacer(),
              MonthlyDetailsButton(onPressed: _showRangeDetailsDialog),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _rangeLabel(t),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_rangeAxisLabel() != null) ...[
          const SizedBox(height: 4),
          Text(
            _rangeAxisLabel()!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white60,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : _daily.isEmpty || !_daily.values.any((v) => v > 0)
              ? _noDataCard(theme)
              : bars,
        ),
      ],
    );
  }

  void _showRangeDetailsDialog() {
    final start = _rangeStart;
    final end = _rangeEnd;
    if (start == null || end == null) return;
    final rows = <MapEntry<String, double>>[];
    if (_range == 'yearly') {
      final Map<String, List<double>> buckets = {};
      _daily.forEach((day, hours) {
        final key = "${day.year}-${day.month.toString().padLeft(2, '0')}";
        buckets.putIfAbsent(key, () => []).add(hours);
      });
      var cursor = DateTime(start.year, start.month, 1);
      final last = DateTime(end.year, end.month, 1);
      while (!cursor.isAfter(last)) {
        final key = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
        final values = buckets[key] ?? const <double>[];
        final avg = values.isEmpty
            ? 0.0
            : values.reduce((a, b) => a + b) / values.length;
        final label = [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "May",
          "Jun",
          "Jul",
          "Aug",
          "Sep",
          "Oct",
          "Nov",
          "Dec",
        ][cursor.month - 1];
        rows.add(MapEntry(label, avg.toDouble()));
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    } else {
      var cursor = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      while (!cursor.isAfter(last)) {
        final key = DateTime(cursor.year, cursor.month, cursor.day);
        final label =
            "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}";
        rows.add(MapEntry(label, _daily[key] ?? 0));
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    final rangeLabel =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} → "
        "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            "Sleep details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: rows.isEmpty
                ? const Text(
                    "No tracked sleep days in this range.",
                    style: TextStyle(color: Colors.white70),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 16),
                    itemBuilder: (ctx, i) {
                      final label = rows[i].key;
                      final hours = rows[i].value;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            _formatHours(hours),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          actions: [
            Text(
              rangeLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricsTab(ThemeData theme) {
    if (!widget.useWhoop) {
      return Center(
        child: Text(
          "Metrics are available for Whoop sleep only.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final m = _whoopMetrics;

    final isLoading = _metricsLoading;
    final napCount = _napCount;
    final napHours = _napHours;
    if (!_metricsHasData && !isLoading) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricsDateHeader(),
            const SizedBox(height: 12),
            _metricsNoDataCard(theme),
          ],
        ),
      );
    }
    final hasMetrics = m != null;
    final sleepHours = hasMetrics ? (m.sleepTimeMs / 3600000.0) : 0.0;
    final bedHours = hasMetrics ? (m.totalInBedMs / 3600000.0) : 0.0;
    final efficiency = hasMetrics ? m.efficiency : 0.0;
    final stage = hasMetrics ? m.stagePercentages : <String, double>{};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricsDateHeader(),
          Center(
            child: Text(
              "These data are for the last tracked day by your device",
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SleepMetricTile(
                  title: "Total sleep",
                  value: (isLoading || !hasMetrics)
                      ? "—"
                      : _formatHours(sleepHours),
                  subtitle: "Light + Deep + REM",
                  accentColor: const Color(0xFF9B8CFF),
                  icon: Icons.nights_stay,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SleepMetricTile(
                  title: "Time in bed",
                  value: (isLoading || !hasMetrics)
                      ? "—"
                      : _formatHours(bedHours),
                  subtitle: "Total in bed",
                  accentColor: const Color(0xFF35B6FF),
                  icon: Icons.king_bed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SleepMetricTile(
            title: "Sleep efficiency",
            value: (isLoading || !hasMetrics)
                ? "—"
                : "${(efficiency * 100).toStringAsFixed(0)}%",
            subtitle: "Sleep time / time in bed",
            accentColor: const Color(0xFF00BFA6),
            icon: Icons.speed,
            child: SleepProgressBar(
              value: (isLoading || !hasMetrics) ? 0 : efficiency,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SleepMetricTile(
                  title: "Disturbances",
                  value: (isLoading || !hasMetrics)
                      ? "—"
                      : m.disturbances.toString(),
                  subtitle: "Night disruptions",
                  accentColor: const Color(0xFFFF8A00),
                  icon: Icons.bolt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SleepMetricTile(
                  title: "Sleep cycles",
                  value: (isLoading || !hasMetrics) ? "—" : m.cycles.toString(),
                  subtitle: "Completed cycles",
                  accentColor: const Color(0xFF6A5AE0),
                  icon: Icons.loop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SleepMetricTile(
            title: "Naps",
            value: (isLoading || !hasMetrics)
                ? "—"
                : (napCount == null
                      ? "—"
                      : "$napCount nap${napCount == 1 ? '' : 's'}"),
            subtitle: isLoading
                ? ""
                : (napHours == null
                      ? "Total —"
                      : "Total ${_formatHours(napHours)}"),
            accentColor: const Color(0xFF35B6FF),
            icon: Icons.bedtime,
          ),
          const SizedBox(height: 12),
          SleepMetricTile(
            title: "Stages",
            value: "",
            subtitle: "Distribution",
            accentColor: const Color(0xFF2D7CFF),
            icon: Icons.pie_chart,
            child: Row(
              children: [
                SleepStageRing(
                  lightPct: (isLoading || !hasMetrics)
                      ? 0
                      : (stage["light"] ?? 0),
                  deepPct: (isLoading || !hasMetrics)
                      ? 0
                      : (stage["slow_wave"] ?? 0),
                  remPct: (isLoading || !hasMetrics) ? 0 : (stage["rem"] ?? 0),
                  size: 120,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stageLegend(
                        color: const Color(0xFF7BD4FF),
                        label: "Light",
                        value: (isLoading || !hasMetrics)
                            ? "—"
                            : "${((stage["light"] ?? 0) * 100).toStringAsFixed(0)}%",
                      ),
                      const SizedBox(height: 6),
                      _stageLegend(
                        color: const Color(0xFF9B8CFF),
                        label: "Deep",
                        value: (isLoading || !hasMetrics)
                            ? "—"
                            : "${((stage["slow_wave"] ?? 0) * 100).toStringAsFixed(0)}%",
                      ),
                      const SizedBox(height: 6),
                      _stageLegend(
                        color: const Color(0xFF00BFA6),
                        label: "REM",
                        value: (isLoading || !hasMetrics)
                            ? "—"
                            : "${((stage["rem"] ?? 0) * 100).toStringAsFixed(0)}%",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeMetricsTab(ThemeData theme) {
    final entry = _nativeMetricsEntry;
    final isLoading = _nativeMetricsLoading;
    final hasData = _nativeMetricsHasData && entry != null;
    if (!hasData && !isLoading) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nativeMetricsDateHeader(theme),
            const SizedBox(height: 12),
            _nativeNoDataCard(theme),
          ],
        ),
      );
    }

    double? sleepHours = entry?.sleepHours;
    final asleepMinutes = entry?.sleepMinutesAsleep;
    final inBedMinutes = entry?.sleepMinutesInBed;
    final awakeMinutes = entry?.sleepMinutesAwake;
    final lightMinutes = entry?.sleepMinutesLight;
    final deepMinutes = entry?.sleepMinutesDeep;
    final remMinutes = entry?.sleepMinutesRem;
    if (sleepHours == null && asleepMinutes != null) {
      sleepHours = asleepMinutes / 60.0;
    }

    final inBedHours = inBedMinutes == null ? null : (inBedMinutes / 60.0);
    final awakeHours = awakeMinutes == null ? null : (awakeMinutes / 60.0);
    final lightHours = lightMinutes == null ? null : (lightMinutes / 60.0);
    final deepHours = deepMinutes == null ? null : (deepMinutes / 60.0);
    final remHours = remMinutes == null ? null : (remMinutes / 60.0);

    double? efficiency;
    if (inBedMinutes != null && inBedMinutes > 0) {
      int? sleepMinutesForEfficiency = asleepMinutes;
      if (sleepMinutesForEfficiency == null && sleepHours != null) {
        sleepMinutesForEfficiency = (sleepHours * 60).round();
      }
      if (sleepMinutesForEfficiency != null) {
        efficiency = sleepMinutesForEfficiency / inBedMinutes;
      }
    }

    final stageTotal =
        (lightMinutes ?? 0) + (deepMinutes ?? 0) + (remMinutes ?? 0);
    final hasStages = stageTotal > 0;
    final lightPct = hasStages ? (lightMinutes! / stageTotal) : 0.0;
    final deepPct = hasStages ? (deepMinutes! / stageTotal) : 0.0;
    final remPct = hasStages ? (remMinutes! / stageTotal) : 0.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nativeMetricsDateHeader(theme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SleepMetricTile(
                  title: "Total sleep",
                  value: (isLoading || !hasData || sleepHours == null)
                      ? "—"
                      : _formatHours(sleepHours),
                  subtitle: "Saved daily metrics",
                  accentColor: const Color(0xFF9B8CFF),
                  icon: Icons.nights_stay,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SleepMetricTile(
                  title: "Time in bed",
                  value: (isLoading || !hasData || inBedHours == null)
                      ? "—"
                      : _formatHours(inBedHours),
                  subtitle: "In-bed duration",
                  accentColor: const Color(0xFF35B6FF),
                  icon: Icons.king_bed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SleepMetricTile(
            title: "Sleep efficiency",
            value: (isLoading || !hasData || efficiency == null)
                ? "—"
                : "${(efficiency * 100).toStringAsFixed(0)}%",
            subtitle: "Sleep time / time in bed",
            accentColor: const Color(0xFF00BFA6),
            icon: Icons.speed,
            child: SleepProgressBar(
              value: (isLoading || !hasData || efficiency == null)
                  ? 0
                  : efficiency,
            ),
          ),
          const SizedBox(height: 12),
          SleepMetricTile(
            title: "Awake time",
            value: (isLoading || !hasData || awakeHours == null)
                ? "—"
                : _formatHours(awakeHours),
            subtitle: "Awake during sleep window",
            accentColor: const Color(0xFFFF8A00),
            icon: Icons.wb_sunny_outlined,
          ),
          const SizedBox(height: 12),
          SleepMetricTile(
            title: "Sleep stages",
            value: "",
            subtitle: "",
            accentColor: const Color(0xFF2D7CFF),
            icon: Icons.pie_chart,
            child: Row(
              children: [
                SleepStageRing(
                  lightPct: (isLoading || !hasStages) ? 0 : lightPct,
                  deepPct: (isLoading || !hasStages) ? 0 : deepPct,
                  remPct: (isLoading || !hasStages) ? 0 : remPct,
                  size: 120,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stageLegend(
                        color: const Color(0xFF7BD4FF),
                        label: "Light",
                        value: (isLoading || !hasStages)
                            ? "—"
                            : "${(lightPct * 100).toStringAsFixed(0)}% (${_formatHours(lightHours ?? 0)})",
                      ),
                      const SizedBox(height: 6),
                      _stageLegend(
                        color: const Color(0xFF9B8CFF),
                        label: "Deep",
                        value: (isLoading || !hasStages)
                            ? "—"
                            : "${(deepPct * 100).toStringAsFixed(0)}% (${_formatHours(deepHours ?? 0)})",
                      ),
                      const SizedBox(height: 6),
                      _stageLegend(
                        color: const Color(0xFF00BFA6),
                        label: "REM",
                        value: (isLoading || !hasStages)
                            ? "—"
                            : "${(remPct * 100).toStringAsFixed(0)}% (${_formatHours(remHours ?? 0)})",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsDateHeader() {
    final dateLabel = "${_monthName(_metricsDate.month)} ${_metricsDate.day}";
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selected = DateTime(
      _metricsDate.year,
      _metricsDate.month,
      _metricsDate.day,
    );
    final canGoNext = selected.isBefore(todayOnly);
    return DateSwitcher(
      label: dateLabel,
      onPrev: () => _changeMetricsDate(-1),
      onNext: () => _changeMetricsDate(1),
      canGoNext: canGoNext,
    );
  }

  Widget _nativeMetricsDateHeader(ThemeData theme) {
    final dateLabel = "${_monthName(_metricsDate.month)} ${_metricsDate.day}";
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selected = DateTime(
      _metricsDate.year,
      _metricsDate.month,
      _metricsDate.day,
    );
    final canGoNext = selected.isBefore(todayOnly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DateSwitcher(
          label: dateLabel,
          onPrev: () => _changeMetricsDate(-1),
          onNext: () => _changeMetricsDate(1),
          canGoNext: canGoNext,
        ),
        const SizedBox(height: 4),
        Text(
          "Saved daily metrics",
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white60,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _nativeNoDataCard(ThemeData theme) {
    final dateLabel = "${_monthName(_metricsDate.month)} ${_metricsDate.day}";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2D7CFF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _nativeMetricsLoading
                  ? Icons.hourglass_bottom
                  : Icons.info_outline,
              color: const Color(0xFF2D7CFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _nativeMetricsLoading
                  ? "Loading sleep metrics..."
                  : "No saved sleep metrics for $dateLabel",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMetricsDate(int delta) {
    final next = DateTime(
      _metricsDate.year,
      _metricsDate.month,
      _metricsDate.day + delta,
    );
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return;
    setState(() => _metricsDate = next);
    if (widget.useWhoop) {
      _loadWhoopMetrics();
    } else {
      _loadNativeMetrics();
    }
  }

  String _monthName(int m) {
    const names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return names[m - 1];
  }

  String _monthShort(int m) {
    const names = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return names[m - 1];
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      case DateTime.sunday:
        return "Sun";
      default:
        return "";
    }
  }

  Widget _stageLegend({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(value, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h}h ${m}m";
  }

  String _formatHoursLabel(double hours) {
    if (hours <= 0) return "0h";
    return _formatHours(hours);
  }

  Widget _metricsNoDataCard(ThemeData theme, {bool loading = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2D7CFF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              loading ? Icons.hourglass_bottom : Icons.info_outline,
              color: const Color(0xFF2D7CFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading
                  ? "Loading sleep metrics..."
                  : "No sleep metrics for this day",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _range == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        _barValueTimer?.cancel();
        setState(() {
          _range = value;
          _selectedBarIndex = null;
        });
        _loadRange();
      },
      selectedColor: AppColors.accent.withValues(alpha: 0.25),
      backgroundColor: AppColors.cardDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBars(ThemeData theme) {
    final hasData = _daily.isNotEmpty && _daily.values.any((v) => v > 0);

    if (!hasData) {
      return _noDataCard(theme);
    }

    final entries = _prepareEntries();
    final maxVal = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final actualMax = maxVal == 0 ? 1.0 : maxVal;
    final midVal = actualMax / 2.0;
    const yAxisWidth = 45.0;
    const yAxisGap = 8.0;
    const labelHeight = 16.0;
    const labelGap = 4.0;

    final isMonthly = _range == 'monthly';
    final isYearly = _range == 'yearly';
    final dense = entries.length > 12;
    final barSpacing = dense ? 2.0 : 4.0;
    final useFixedSlots = dense || isMonthly || isYearly;
    final showLabels = _range != 'monthly';
    final chartEntries = entries
        .map((e) => RangedBarChartEntry(axisLabel: e.axisLabel, value: e.value))
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 34,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child:
                        (_selectedBarIndex == null ||
                            _selectedBarIndex! < 0 ||
                            _selectedBarIndex! >= entries.length)
                        ? const SizedBox.shrink()
                        : Container(
                            key: ValueKey<int>(_selectedBarIndex!),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1826),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF35B6FF,
                                ).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              "${entries[_selectedBarIndex!].detailLabel}  ${_formatHours(entries[_selectedBarIndex!].value)}",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RangedBarChart(
                  entries: chartEntries,
                  maxValue: actualMax,
                  midValue: midVal,
                  formatValue: _formatHoursLabel,
                  gradient: const [Color(0xFF35B6FF), Color(0xFF9B8CFF)],
                  selectedGradient: const [
                    Color(0xFF6BE1FF),
                    Color(0xFFB7A9FF),
                  ],
                  selectedIndex: _selectedBarIndex,
                  onBarTap: _onBarTap,
                  showAxisLabels: showLabels,
                  useFixedSlots: useFixedSlots,
                  barSpacing: barSpacing,
                  minBarWidth: 4.0,
                  yAxisWidth: yAxisWidth,
                  yAxisGap: yAxisGap,
                  labelHeight: labelHeight,
                  labelGap: labelGap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _rangeLabel(String Function(String) t, {bool short = false}) {
    switch (_range) {
      case 'monthly':
        final ref = _rangeStart ?? DateTime.now();
        final days = DateTime(ref.year, ref.month + 1, 0).day;
        return short ? "${days}d" : "Last $days days";
      case 'yearly':
        return short ? "1y" : t("range_last_year");
      case 'weekly':
      default:
        return short ? "7d" : t("range_last7");
    }
  }

  Widget _summaryCard({required String title, required String value}) {
    return Expanded(
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Prepares chart entries based on range:
  /// - weekly/monthly: daily bars
  /// - yearly: grouped by month (average hours)
  List<_SleepBarEntry> _prepareEntries() {
    if (_daily.isEmpty) return [];
    if (_range != 'yearly') {
      final start = _rangeStart;
      final end = _rangeEnd;
      if (start == null || end == null) {
        final entries = _daily.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return entries
            .map(
              (e) => _SleepBarEntry(
                axisLabel: "",
                detailLabel: "${e.key.day} ${_monthShort(e.key.month)}",
                value: e.value,
              ),
            )
            .toList();
      }
      final items = <_SleepBarEntry>[];
      var cursor = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      final lastDay = last.day;
      while (!cursor.isAfter(last)) {
        final key = DateTime(cursor.year, cursor.month, cursor.day);
        String label = "";
        if (_range == 'weekly') {
          label = _weekdayShort(cursor.weekday);
        } else {
          final dayNum = cursor.day;
          final midDay = (lastDay / 2).round();
          final showLabel =
              dayNum == 1 || dayNum == midDay || dayNum == lastDay;
          label = showLabel ? dayNum.toString() : "";
        }
        final detail = _range == 'weekly'
            ? "${_weekdayShort(cursor.weekday)}, ${cursor.day} ${_monthShort(cursor.month)}"
            : "${cursor.day} ${_monthShort(cursor.month)}";
        items.add(
          _SleepBarEntry(
            axisLabel: label,
            detailLabel: detail,
            value: _daily[key] ?? 0,
          ),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      return items;
    }

    // Yearly: group by month and use average hours per month.
    final start = _rangeStart;
    final end = _rangeEnd;
    if (start == null || end == null) {
      return [];
    }

    final Map<String, List<double>> buckets = {};
    _daily.forEach((day, hours) {
      final key = "${day.year}-${day.month.toString().padLeft(2, '0')}";
      buckets.putIfAbsent(key, () => []).add(hours);
    });

    final entries = <_SleepBarEntry>[];
    var cursor = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(last)) {
      final key = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
      final values = buckets[key] ?? const <double>[];
      final avg = values.isEmpty
          ? 0.0
          : values.reduce((a, b) => a + b) / values.length;
      entries.add(
        _SleepBarEntry(
          axisLabel: _monthShort(cursor.month),
          detailLabel: "${_monthShort(cursor.month)} ${cursor.year}",
          value: avg.toDouble(),
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return entries;
  }

  void _onBarTap(int index) {
    _barValueTimer?.cancel();
    if (!mounted) return;
    setState(() => _selectedBarIndex = index);
    _barValueTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _selectedBarIndex = null);
    });
  }

  String? _rangeAxisLabel() {
    switch (_range) {
      case 'weekly':
        return "Mon — Sun";
      case 'monthly':
        final ref = _rangeStart ?? DateTime.now();
        final lastDay = DateTime(ref.year, ref.month + 1, 0).day;
        return "1st — ${_ordinal(lastDay)}";
      case 'yearly':
        return "Jan — Dec";
      default:
        return null;
    }
  }

  String _ordinal(int value) {
    if (value % 100 >= 11 && value % 100 <= 13) {
      return "${value}th";
    }
    switch (value % 10) {
      case 1:
        return "${value}st";
      case 2:
        return "${value}nd";
      case 3:
        return "${value}rd";
      default:
        return "${value}th";
    }
  }

  Widget _noDataCard(ThemeData theme) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context).translate("no_sleep_range"),
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _promptManualEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Add sleep manually"),
          ),
        ],
      ),
    );
  }

  Future<void> _promptManualEntry() async {
    final controller = TextEditingController(
      text: _todaySleepHours() > 0 ? _todaySleepHours().toStringAsFixed(1) : '',
    );
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            "Add sleep hours",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "e.g. 7.5",
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'reset'),
              child: const Text("Reset"),
            ),
            TextButton(
              onPressed: () {
                final val = double.tryParse(controller.text.trim());
                if (val != null && val > 0) {
                  Navigator.pop(ctx, val);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (result == 'reset') {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await SleepService().clearManualEntry(day);
      if (mounted) {
        _loadRange(force: true);
      }
      return;
    }

    if (result is double) {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await SleepService().saveManualEntry(day, result);
      if (mounted) {
        _loadRange(force: true);
      }
    }
  }

  double _todaySleepHours() {
    final today = DateTime.now();
    final dayKey = DateTime(today.year, today.month, today.day);
    return _daily[dayKey] ?? 0;
  }
}

class _SleepBarEntry {
  const _SleepBarEntry({
    required this.axisLabel,
    required this.detailLabel,
    required this.value,
  });

  final String axisLabel;
  final String detailLabel;
  final double value;
}

class _WhoopSleepMetrics {
  const _WhoopSleepMetrics({
    required this.totalInBedMs,
    required this.awakeMs,
    required this.noDataMs,
    required this.lightMs,
    required this.slowWaveMs,
    required this.remMs,
    required this.disturbances,
    required this.cycles,
  });

  final int totalInBedMs;
  final int awakeMs;
  final int noDataMs;
  final int lightMs;
  final int slowWaveMs;
  final int remMs;
  final int disturbances;
  final int cycles;

  int get sleepTimeMs => lightMs + slowWaveMs + remMs;

  double get efficiency =>
      totalInBedMs > 0 ? (sleepTimeMs / totalInBedMs) : 0.0;

  Map<String, double> get stagePercentages {
    final total = sleepTimeMs;
    if (total <= 0) {
      return {"light": 0, "slow_wave": 0, "rem": 0};
    }
    return {
      "light": lightMs / total,
      "slow_wave": slowWaveMs / total,
      "rem": remMs / total,
    };
  }

  static _WhoopSleepMetrics? fromSleep(Map<String, dynamic> sleep) {
    final score = sleep["score"];
    if (score is! Map<String, dynamic>) return null;
    final stage = score["stage_summary"];
    if (stage is! Map<String, dynamic>) return null;

    int _int(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return _WhoopSleepMetrics(
      totalInBedMs: _int(stage["total_in_bed_time_milli"]),
      awakeMs: _int(stage["total_awake_time_milli"]),
      noDataMs: _int(stage["total_no_data_time_milli"]),
      lightMs: _int(stage["total_light_sleep_time_milli"]),
      slowWaveMs: _int(stage["total_slow_wave_sleep_time_milli"]),
      remMs: _int(stage["total_rem_sleep_time_milli"]),
      disturbances: _int(stage["disturbance_count"]),
      cycles: _int(stage["sleep_cycle_count"]),
    );
  }
}
