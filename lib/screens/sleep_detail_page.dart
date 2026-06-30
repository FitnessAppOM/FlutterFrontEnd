import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/components/taqa_progress_widget_card.dart';
import '../TaqaUI/components/taqa_sleep_stages_wide_card.dart';
import '../TaqaUI/components/taqa_steps_ui.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../core/account_storage.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../services/health/sleep_service.dart';
import '../services/whoop/whoop_sleep_service.dart';
import '../services/whoop/whoop_widget_data_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/charts/ranged_bar_chart.dart';
import '../widgets/common/date_switcher.dart';

class SleepDetailPage extends StatefulWidget {
  const SleepDetailPage({super.key, this.useWhoop = false, this.initialDate});

  final bool useWhoop;
  final DateTime? initialDate;

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
  static final Map<String, _WhoopSleepMetrics?> _metricsCache = {};
  static final Map<String, DailyMetricsEntry?> _nativeMetricsCache = {};
  static final Map<String, int?> _napCountCache = {};
  static final Map<String, double?> _napHoursCache = {};
  static final Map<String, bool> _metricsHasDataCache = {};
  int? _selectedBarIndex;
  Timer? _barValueTimer;
  late final DateTime _anchorDate;
  int _topTabIndex = 0;

  static const _sleepGoalKey = "dashboard_sleep_goal";
  static final Map<String, Map<DateTime, double>> _rangeDataCache = {};

  String _dayToken(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Future<String> _userDayCacheKey(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    final scopedUserId = userId ?? 0;
    return "$scopedUserId|${_dayToken(date)}";
  }

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
    _anchorDate = _resolvedAnchorDate(widget.initialDate);
    _metricsDate = _anchorDate;
    if (widget.useWhoop) {
      _metricsLoading = true;
    } else {
      _nativeMetricsLoading = true;
    }
    _loadGoal();
    _loadRange();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _resolvedAnchorDate(DateTime? date) {
    final today = _dateOnly(DateTime.now());
    final requested = _dateOnly(date ?? today);
    return requested.isAfter(today) ? today : requested;
  }

  bool get _isCurrentDayView =>
      _dateOnly(_anchorDate) == _dateOnly(DateTime.now());
  bool get _canManualEdit => _isCurrentDayView && _range == 'weekly';

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
    if (!_canManualEdit) return;
    final text = await showTaqaTextValueDialog(
      context: context,
      title: AppLocalizations.of(context).translate("common_edit_goal_title"),
      initialValue: (_goal ?? 8.0).toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final res = text == null ? null : double.tryParse(text);
    if (res != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(_sleepGoalKey, res);
      if (!mounted) return;
      setState(() => _goal = res);
    }
  }

  Future<void> _loadRange({bool force = false}) async {
    try {
      final today = _dateOnly(DateTime.now());
      final reference = _anchorDate.isAfter(today) ? today : _anchorDate;
      DateTime start;
      DateTime end;
      switch (_range) {
        case 'monthly':
          start = DateTime(reference.year, reference.month, 1);
          end = DateTime(reference.year, reference.month + 1, 0);
          break;
        case 'yearly':
          // Current calendar year only (Jan 1 -> Dec 31)
          start = DateTime(reference.year, 1, 1);
          end = DateTime(reference.year, 12, 31);
          break;
        case 'weekly':
        default:
          start = reference.subtract(Duration(days: reference.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
      }
      final effectiveEnd = today.isBefore(end) ? today : end;
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
        final todayKey = today;
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
    final cacheKey = await _userDayCacheKey(dayKey);
    final cachedHasData = _metricsHasDataCache[cacheKey];
    final cachedMetrics = _metricsCache[cacheKey];
    final hasCache = cachedMetrics != null || cachedHasData != null;
    setState(() {
      if (hasCache) {
        _whoopMetrics = cachedMetrics;
        _napCount = _napCountCache[cacheKey];
        _napHours = _napHoursCache[cacheKey];
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
      _metricsCache[cacheKey] = metrics;
      _napCountCache[cacheKey] = napCount is num
          ? napCount.round()
          : int.tryParse("$napCount");
      _napHoursCache[cacheKey] = napHours is num
          ? napHours.toDouble()
          : double.tryParse("$napHours");
      _metricsHasDataCache[cacheKey] = hasData;
      setState(() {
        _whoopMetrics = metrics;
        _napCount = _napCountCache[cacheKey];
        _napHours = _napHoursCache[cacheKey];
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
    final cacheKey = await _userDayCacheKey(dayKey);
    final isToday = _isSameDay(dayKey, _onlyDate(DateTime.now()));
    final hasCache = _nativeMetricsCache.containsKey(cacheKey);
    final canUseCache = hasCache && !force && !isToday;

    if (!mounted) return;
    setState(() {
      if (canUseCache) {
        final cached = _nativeMetricsCache[cacheKey];
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
        entry = _nativeMetricsCache[cacheKey];
      }
    }
    if (!mounted || requestId != _nativeMetricsReqId) return;

    final resolved = await _resolveNativeSleepEntry(
      dayKey: dayKey,
      entry: entry,
    );
    if (!mounted || requestId != _nativeMetricsReqId) return;

    _nativeMetricsCache[cacheKey] = resolved;
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
        centerTitle: true,
        title: Text(
          t("sleep_title"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 25 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: false,
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: Padding(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: TaqaUiScale.w(171),
                  child: TaqaRangeTab(
                    label: t("sleep_trend_tab"),
                    selected: _topTabIndex == 0,
                    onTap: () {
                      if (_topTabIndex == 0) return;
                      setState(() => _topTabIndex = 0);
                    },
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(15)),
                SizedBox(
                  width: TaqaUiScale.w(171),
                  child: TaqaRangeTab(
                    label: t("sleep_metrics_tab"),
                    selected: _topTabIndex == 1,
                    onTap: () {
                      if (_topTabIndex == 1) return;
                      setState(() => _topTabIndex = 1);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(14)),
            Expanded(
              child: _topTabIndex == 0
                  ? _buildTrendsTab(t, theme, bars)
                  : (widget.useWhoop
                        ? _buildMetricsTab(theme)
                        : _buildNativeMetricsTab(theme)),
            ),
          ],
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
        Row(
          children: [
            SizedBox(
              width: TaqaUiScale.w(109),
              child: TaqaRangeTab(
                label: t("range_weekly"),
                selected: _range == 'weekly',
                onTap: () => _onRangeTabTap('weekly'),
              ),
            ),
            SizedBox(width: TaqaUiScale.w(15)),
            SizedBox(
              width: TaqaUiScale.w(109),
              child: TaqaRangeTab(
                label: t("range_monthly"),
                selected: _range == 'monthly',
                onTap: () => _onRangeTabTap('monthly'),
              ),
            ),
            SizedBox(width: TaqaUiScale.w(15)),
            SizedBox(
              width: TaqaUiScale.w(109),
              child: TaqaRangeTab(
                label: t("range_yearly"),
                selected: _range == 'yearly',
                onTap: () => _onRangeTabTap('yearly'),
              ),
            ),
          ],
        ),
        SizedBox(height: TaqaUiScale.h(19)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                t("sleep_goal_btn").replaceAll(
                  "{value}",
                  (_goal ?? 8.0).toStringAsFixed(1),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(25),
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
            ),
            if (_canManualEdit) ...[
              TaqaTagButton(
                icon: Icons.edit_outlined,
                label: t("common_edit_goal_button"),
                onTap: _editGoal,
              ),
            ],
            if (_canManualEdit && !widget.useWhoop) ...[
              SizedBox(width: TaqaUiScale.w(8)),
              TaqaTagButton(
                icon: Icons.add,
                label: t("common_add_button"),
                onTap: _promptManualEntry,
              ),
            ],
          ],
        ),
        SizedBox(height: TaqaUiScale.h(19)),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : _daily.isEmpty || !_daily.values.any((v) => v > 0)
              ? TaqaEmptyCard(
                  title: t("dash_no_sleep_data"),
                  subtitle: t("common_no_records_in_range"),
                  icon: Icons.bedtime_outlined,
                )
              : bars,
        ),
      ],
    );
  }

  void _showRangeDetailsDialog() {
    final t = AppLocalizations.of(context).translate;
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
          title: Text(
            t("sleep_details_dialog_title"),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: rows.isEmpty
                ? Text(
                    t("sleep_no_tracked_days"),
                    style: const TextStyle(color: Colors.white70),
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
              child: Text(t("common_close")),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricsTab(ThemeData theme) {
    final t = AppLocalizations.of(context).translate;
    if (!widget.useWhoop) {
      return Center(
        child: Text(
          t("sleep_metrics_whoop_only"),
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
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaEmptyCard(
              title: t("sleep_no_metrics_title"),
              subtitle: "${_monthName(_metricsDate.month)} ${_metricsDate.day}",
              icon: Icons.bedtime_outlined,
            ),
          ],
        ),
      );
    }
    final hasMetrics = m != null;
    final sleepHours = hasMetrics ? (m.sleepTimeMs / 3600000.0) : 0.0;
    final bedHours = hasMetrics ? (m.totalInBedMs / 3600000.0) : 0.0;
    final sleepGoalHours = (_goal != null && _goal! > 0) ? _goal! : 8.0;
    final sleepProgress = hasMetrics ? (sleepHours / sleepGoalHours) : 0.0;
    final bedProgress = hasMetrics ? (bedHours / sleepGoalHours) : 0.0;
    final efficiency = hasMetrics ? m.efficiency : 0.0;
    final stage = hasMetrics ? m.stagePercentages : <String, double>{};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricsDateHeader(),
          SizedBox(height: TaqaUiScale.h(12)),
          Row(
            children: [
              Expanded(
                child: _buildArcSleepMetricCard(
                  title: t("sleep_total_sleep_title"),
                  valueText: (isLoading || !hasMetrics)
                      ? "0.0"
                      : _formatHours(sleepHours),
                  subtitle: t("sleep_light_deep_rem_subtitle"),
                  progress: sleepProgress,
                  loading: isLoading,
                ),
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: _buildArcSleepMetricCard(
                  title: t("sleep_time_in_bed_title"),
                  valueText: (isLoading || !hasMetrics)
                      ? "0.0"
                      : _formatHours(bedHours),
                  subtitle: t("sleep_total_in_bed_subtitle"),
                  progress: bedProgress,
                  loading: isLoading,
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          _buildEfficiencyMetricCard(
            efficiency: (isLoading || !hasMetrics) ? 0.0 : efficiency,
            loading: isLoading,
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          Row(
            children: [
              SizedBox(
                width: TaqaUiScale.w(109),
                height: TaqaUiScale.h(109),
                child: _buildCompactSleepStatCard(
                  title: t("sleep_disturbances_title"),
                  valueText: (isLoading || !hasMetrics)
                      ? "0"
                      : m.disturbances.toString(),
                  subtitle: t("sleep_night_disruptions_subtitle"),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              SizedBox(
                width: TaqaUiScale.w(109),
                height: TaqaUiScale.h(109),
                child: _buildCompactSleepStatCard(
                  title: t("sleep_cycles_title"),
                  valueText: (isLoading || !hasMetrics)
                      ? "0"
                      : m.cycles.toString(),
                  subtitle: t("sleep_completed_cycles_subtitle"),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              SizedBox(
                width: TaqaUiScale.w(109),
                height: TaqaUiScale.h(109),
                child: _buildCompactSleepStatCard(
                  title: t("sleep_naps_title"),
                  valueText: (isLoading || !hasMetrics)
                      ? "0"
                      : (napCount == null ? "0" : napCount.toString()),
                  subtitle: isLoading
                      ? t("sleep_naps_total_subtitle").replaceAll("{hours}", "0.0")
                      : (napHours == null
                            ? t("sleep_naps_total_subtitle").replaceAll("{hours}", "0.0")
                            : t("sleep_naps_total_subtitle").replaceAll(
                                "{hours}",
                                _formatHours(napHours),
                              )),
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaSleepStagesWideCard(
            title: t("sleep_total_sleep_title"),
            centerLabel: t("sleep_stages_label"),
            lightPct: (isLoading || !hasMetrics) ? 0 : (stage["light"] ?? 0),
            deepPct: (isLoading || !hasMetrics) ? 0 : (stage["slow_wave"] ?? 0),
            remPct: (isLoading || !hasMetrics) ? 0 : (stage["rem"] ?? 0),
          ),

        ],
      ),
    );
  }

  Widget _buildNativeMetricsTab(ThemeData theme) {
    final t = AppLocalizations.of(context).translate;
    final entry = _nativeMetricsEntry;
    final isLoading = _nativeMetricsLoading;
    final hasData = _nativeMetricsHasData && entry != null;
    if (!hasData && !isLoading) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _nativeMetricsDateHeader(),
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaEmptyCard(
              title: t("sleep_no_metrics_title"),
              subtitle: "${_monthName(_metricsDate.month)} ${_metricsDate.day}",
              icon: Icons.bedtime_outlined,
            ),
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
    final sleepGoalHours = (_goal != null && _goal! > 0) ? _goal! : 8.0;
    final sleepProgress = sleepHours == null
        ? 0.0
        : (sleepHours / sleepGoalHours);
    final inBedProgress = inBedHours == null
        ? 0.0
        : (inBedHours / sleepGoalHours);

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
          _nativeMetricsDateHeader(),
          SizedBox(height: TaqaUiScale.h(12)),
          Row(
            children: [
              Expanded(
                child: _buildArcSleepMetricCard(
                  title: t("sleep_total_sleep_title"),
                  valueText: (isLoading || !hasData || sleepHours == null)
                      ? "0.0"
                      : _formatHours(sleepHours),
                  subtitle: t("sleep_saved_daily_metrics_subtitle"),
                  progress: sleepProgress,
                  loading: isLoading,
                ),
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: _buildArcSleepMetricCard(
                  title: t("sleep_time_in_bed_title"),
                  valueText: (isLoading || !hasData || inBedHours == null)
                      ? "0.0"
                      : _formatHours(inBedHours),
                  subtitle: t("sleep_in_bed_duration_subtitle"),
                  progress: inBedProgress,
                  loading: isLoading,
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          _buildEfficiencyMetricCard(
            efficiency: (isLoading || !hasData || efficiency == null)
                ? 0.0
                : efficiency,
            loading: isLoading,
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaLinearMetricCard(
            title: t("sleep_awake_time_title"),
            valueText: (isLoading || !hasData || awakeHours == null)
                ? "0.0"
                : _formatHours(awakeHours),
            subtitle: t("sleep_awake_during_window_subtitle"),
            progress: 0.0,
            loading: isLoading,
            lightSurface: true,
            showBar: false,
            keepBarSpaceWhenHidden: false,
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaSleepStagesWideCard(
            title: t("sleep_total_sleep_title"),
            centerLabel: t("sleep_stages_label"),
            lightPct: (isLoading || !hasStages) ? 0 : lightPct,
            deepPct: (isLoading || !hasStages) ? 0 : deepPct,
            remPct: (isLoading || !hasStages) ? 0 : remPct,
          ),
        ],
      ),
    );
  }

  Widget _metricsDateHeader() {
    final dateLabel =
        "${_weekdayShort(_metricsDate.weekday).toUpperCase()}, ${_monthName(_metricsDate.month).toUpperCase()} ${_metricsDate.day}";
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
      labelStyle: TextStyle(
        color: TaqaUiColors.unnamedColor1c1d17,
        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
        fontSize: TaqaUiScale.sp(8),
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 10 / 8,
      ),
      iconColor: TaqaUiColors.unnamedColor1c1d17,
      labelWidth: TaqaUiScale.w(62),
    );
  }

  Widget _nativeMetricsDateHeader() {
    final dateLabel =
        "${_weekdayShort(_metricsDate.weekday).toUpperCase()}, ${_monthName(_metricsDate.month).toUpperCase()} ${_metricsDate.day}";
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
          labelStyle: const TextStyle(
            color: TaqaUiColors.unnamedColor1c1d17,
            fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
            fontSize: 8,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
          iconColor: TaqaUiColors.unnamedColor1c1d17,
          labelWidth: 100,
        ),
      ],
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

  Widget _buildArcSleepMetricCard({
    required String title,
    required String valueText,
    required String subtitle,
    required double progress,
    required bool loading,
  }) {
    return TaqaProgressWidgetCard(
      title: title,
      valueText: valueText,
      goalText: subtitle,
      progress: loading ? 0.0 : progress,
      loading: loading,
      topRight: const SizedBox.shrink(),
      lightSurface: true,
    );
  }

  Widget _buildEfficiencyMetricCard({
    required double efficiency,
    required bool loading,
  }) {
    final clampedEfficiency = loading ? 0.0 : efficiency.clamp(0.0, 1.0);
    return TaqaLinearMetricCard(
      title: AppLocalizations.of(context).translate("sleep_efficiency_title"),
      valueText: "${(clampedEfficiency * 100).toStringAsFixed(0)}%",
      subtitle: AppLocalizations.of(
        context,
      ).translate("sleep_efficiency_subtitle"),
      progress: clampedEfficiency,
      loading: loading,
      lightSurface: true,
    );
  }

  Widget _buildCompactSleepStatCard({
    required String title,
    required String valueText,
    required String subtitle,
  }) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17,
              letterSpacing: 0,
              height: 10 / 8,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(30)),
          Text(
            valueText,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(25),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.unnamedColor1c1d17,
              height: 1,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(5)),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17,
              letterSpacing: 0,
              height: 13 / 8,
            ),
          ),
        ],
      ),
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

  void _onRangeTabTap(String value) {
    if (_range == value) return;
    _barValueTimer?.cancel();
    setState(() {
      _range = value;
      _selectedBarIndex = null;
    });
    _loadRange();
  }

  Widget _buildBars(ThemeData theme) {
    final hasData = _daily.isNotEmpty && _daily.values.any((v) => v > 0);

    if (!hasData) {
      final t = AppLocalizations.of(context).translate;
      return TaqaEmptyCard(
        title: t("dash_no_sleep_data"),
        subtitle: t("common_no_records_in_range"),
        icon: Icons.bedtime_outlined,
      );
    }

    final entries = _prepareEntries();
    final maxVal = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final actualMax = maxVal == 0 ? 1.0 : maxVal;
    final midVal = actualMax / 2.0;
    final yAxisWidth = TaqaUiScale.w(45);
    final yAxisGap = TaqaUiScale.w(8);
    final labelHeight = TaqaUiScale.h(16);
    final labelGap = TaqaUiScale.h(4);

    final isMonthly = _range == 'monthly';
    final isYearly = _range == 'yearly';
    final dense = entries.length > 12;
    final barSpacing = dense ? TaqaUiScale.w(2) : TaqaUiScale.w(4);
    final useFixedSlots = dense || isMonthly || isYearly;
    final showLabels = _range != 'monthly';
    final chartEntries = entries
        .map((e) => RangedBarChartEntry(axisLabel: e.axisLabel, value: e.value))
        .toList();
    final total = _daily.values.fold<double>(0.0, (a, b) => a + b);
    final avg = _daily.isEmpty ? 0.0 : total / _daily.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: TaqaUiScale.insetsLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiScale.radius(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _range == 'weekly'
                    ? AppLocalizations.of(context).translate("range_last7")
                    : _range == 'yearly'
                    ? AppLocalizations.of(context).translate("range_last_year")
                    : _rangeLabel(AppLocalizations.of(context).translate),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w700,
                  height: 25 / 15,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(5)),
              Text(
                AppLocalizations.of(context)
                    .translate("sleep_avg_total")
                    .replaceAll("{avg}", avg.toStringAsFixed(1))
                    .replaceAll("{total}", total.toStringAsFixed(1)),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(10),
                  fontWeight: FontWeight.w400,
                  height: 11 / 10,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(10)),
              SizedBox(
                height: TaqaUiScale.h(34),
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
                            padding: TaqaUiScale.insetsLTRB(12, 7, 12, 7),
                            decoration: BoxDecoration(
                              color: TaqaUiColors.charcoal,
                              borderRadius: TaqaUiScale.radius(10),
                              border: Border.all(
                                color: TaqaUiColors.lime.withValues(alpha: 0.45),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              "${entries[_selectedBarIndex!].detailLabel}  ${_formatHours(entries[_selectedBarIndex!].value)}",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: TaqaUiScale.sp(10),
                                fontWeight: FontWeight.w700,
                                color: TaqaUiColors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(height: TaqaUiScale.h(10)),
              Expanded(
                child: RangedBarChart(
                  entries: chartEntries,
                  maxValue: actualMax,
                  midValue: midVal,
                  formatValue: _formatHoursLabel,
                  gradient: const [Color(0xFF404040), Color(0xFF1C1D17)],
                  selectedGradient: const [
                    Color(0xFFE4E93B),
                    Color(0xFFC9CF36),
                  ],
                  selectedIndex: _selectedBarIndex,
                  onBarTap: _onBarTap,
                  showAxisLabels: showLabels,
                  useFixedSlots: useFixedSlots,
                  barSpacing: barSpacing,
                  minBarWidth: TaqaUiScale.w(4),
                  yAxisWidth: yAxisWidth,
                  yAxisGap: yAxisGap,
                  labelHeight: labelHeight,
                  labelGap: labelGap,
                  axisTextColor: TaqaUiColors.unnamedColor1c1d17,
                  labelTextColor: TaqaUiColors.unnamedColor1c1d17,
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
        final ref = _rangeStart ?? _anchorDate;
        final days = DateTime(ref.year, ref.month + 1, 0).day;
        return short ? "${days}d" : t("range_last_n_days").replaceAll("{n}", "$days");
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
        final ref = _rangeStart ?? _anchorDate;
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

  Future<void> _promptManualEntry() async {
    if (!_canManualEdit) return;
    final text = await showTaqaTextValueDialog(
      context: context,
      title: AppLocalizations.of(context).translate("sleep_add_dialog_title"),
      initialValue: _todaySleepHours() > 0
          ? _todaySleepHours().toStringAsFixed(1)
          : '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final result = text == null ? null : double.tryParse(text);
    if (result != null && result > 0) {
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
