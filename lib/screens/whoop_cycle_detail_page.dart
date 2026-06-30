import 'package:flutter/material.dart';
import '../core/account_storage.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../services/whoop/whoop_cycle_service.dart';
import '../widgets/recovery/recovery_metric_card.dart';
import '../widgets/charts/simple_line_chart.dart';
import '../widgets/common/date_switcher.dart';

class WhoopCycleDetailPage extends StatefulWidget {
  const WhoopCycleDetailPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<WhoopCycleDetailPage> createState() => _WhoopCycleDetailPageState();
}

class _WhoopCycleDetailPageState extends State<WhoopCycleDetailPage> {
  bool _loading = true;
  late DateTime _selectedDate;
  Map<DateTime, Map<String, dynamic>> _daily = {};
  static final Map<DateTime, Map<String, dynamic>> _dailyCache = {};
  static final Map<String, Map<DateTime, Map<String, dynamic>>> _rangeCache =
      {};
  static int? _cacheUserId;
  int _reqId = 0;

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _effectiveCycleDay(DateTime selected) {
    // Strain/cycle is same-day: the selected day maps to its own cycle.
    return DateTime(selected.year, selected.month, selected.day);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _loadRange();
  }

  Future<void> _loadRange() async {
    final requestId = ++_reqId;
    final day = _effectiveCycleDay(_selectedDate);
    final start = day.subtract(const Duration(days: 6));
    final end = day;
    final userId = await AccountStorage.getUserId();
    if (_cacheUserId != userId) {
      _cacheUserId = userId;
      _dailyCache.clear();
      _rangeCache.clear();
    }
    final rangeKey = _rangeKey(userId, start, end);

    final cachedRange = _rangeCache[rangeKey];
    if (cachedRange != null) {
      if (!mounted) return;
      if (requestId != _reqId) return;
      setState(() {
        _daily = cachedRange;
        _loading = false;
      });
      return;
    }

    final hasSelectedDayCached = _dailyCache.containsKey(day);
    setState(() => _loading = !hasSelectedDayCached);
    try {
      final data = await WhoopCycleService().fetchDailyCycles(
        start: start,
        end: end,
      );
      if (!mounted) return;
      if (requestId != _reqId) return;
      setState(() {
        _daily = data;
        _dailyCache.addAll(data);
        _rangeCache[rangeKey] = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (requestId != _reqId) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayKey = _effectiveCycleDay(selectedDay);
    final bool isPastDay = _isPastDay(dayKey);
    final metrics = _daily[dayKey] ?? _dailyCache[dayKey];
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate("whoop_daily_cycle_title")),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(selectedDay),
            const SizedBox(height: 14),
            _metricsGrid(
              metrics,
              isLoading: _loading,
              showEmptyAsDash: isPastDay,
            ),
            if (!_hideTrendForNoData(metrics)) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  AppLocalizations.of(context).translate("whoop_avg_hr_trend"),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SimpleLineChart(
                    values: _avgHrSeries(),
                    color: const Color(0xFFE84C4F),
                    showPoints: true,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (!_loading) _avgHrNote(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(DateTime date) {
    final dateLabel = "${_monthName(date.month)} ${date.day}";
    return DateSwitcher(
      label: dateLabel,
      onPrev: () => _changeDay(-1),
      onNext: () => _changeDay(1),
      canGoNext: _canGoNext,
    );
  }

  Widget _metricsGrid(
    Map<String, dynamic>? metrics, {
    required bool isLoading,
    required bool showEmptyAsDash,
  }) {
    if (metrics == null && isLoading) {
      return const SizedBox.shrink();
    }

    if (metrics == null && !showEmptyAsDash) {
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
              child: const Icon(Icons.info_outline, color: Color(0xFF2D7CFF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).translate("whoop_no_cycle_data"),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (metrics == null && showEmptyAsDash) {
      return _dashMetricsGrid();
    }

    final t = AppLocalizations.of(context).translate;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_strain_label"),
                value: _fmt(metrics?["strain"]),
                unit: "",
                icon: Icons.bolt,
                accent: const Color(0xFFFF8A00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_avg_hr_label"),
                value: _fmt(metrics?["avg_hr"]),
                unit: "bpm",
                icon: Icons.favorite,
                accent: const Color(0xFFE84C4F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_max_hr_label"),
                value: _fmt(metrics?["max_hr"]),
                unit: "bpm",
                icon: Icons.show_chart,
                accent: const Color(0xFF7BD4FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_energy_label"),
                value: _fmt(metrics?["kilojoules"]),
                unit: "kJ",
                icon: Icons.local_fire_department,
                accent: const Color(0xFFB8E91E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dashMetricsGrid() {
    final t = AppLocalizations.of(context).translate;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_strain_label"),
                value: "—",
                unit: "",
                icon: Icons.bolt,
                accent: const Color(0xFFFF8A00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_avg_hr_label"),
                value: "—",
                unit: "bpm",
                icon: Icons.favorite,
                accent: const Color(0xFFE84C4F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_max_hr_label"),
                value: "—",
                unit: "bpm",
                icon: Icons.show_chart,
                accent: const Color(0xFF7BD4FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: t("whoop_energy_label"),
                value: "—",
                unit: "kJ",
                icon: Icons.local_fire_department,
                accent: const Color(0xFFB8E91E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _hideTrendForNoData(Map<String, dynamic>? metrics) {
    return metrics == null;
  }

  List<double?> _avgHrSeries() {
    final day = _effectiveCycleDay(_selectedDate);
    final start = day.subtract(const Duration(days: 6));
    final values = <double?>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final dayKey = DateTime(d.year, d.month, d.day);
      final v = (_daily[dayKey] ?? _dailyCache[dayKey])?["avg_hr"];
      if (v is num) {
        values.add(v.toDouble());
      } else {
        values.add(null);
      }
    }
    return values;
  }

  Widget _avgHrNote() {
    final dayKey = _effectiveCycleDay(_selectedDate);
    final yesterdayKey = dayKey.subtract(const Duration(days: 1));
    final today = (_daily[dayKey] ?? _dailyCache[dayKey])?["avg_hr"];
    final yesterday =
        (_daily[yesterdayKey] ?? _dailyCache[yesterdayKey])?["avg_hr"];
    if (today is! num || yesterday is! num) {
      return const SizedBox.shrink();
    }
    final delta = (today.toDouble() - yesterday.toDouble());
    final up = delta >= 0;
    final t = AppLocalizations.of(context).translate;
    final text = up
        ? t("whoop_avg_hr_up").replaceAll("{delta}", delta.toStringAsFixed(1))
        : t("whoop_avg_hr_down").replaceAll("{delta}", delta.abs().toStringAsFixed(1));
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (up ? const Color(0xFF4CD964) : const Color(0xFFFF8A00))
                .withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              up ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: up ? const Color(0xFF4CD964) : const Color(0xFFFF8A00),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: up ? const Color(0xFF4CD964) : const Color(0xFFFF8A00),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeDay(int delta) {
    final next = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + delta,
    );
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return;
    setState(() {
      _selectedDate = next;
    });
    _loadRange();
  }

  bool get _canGoNext {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return selected.isBefore(todayOnly);
  }

  bool _isPastDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today);
  }

  String _rangeKey(int? userId, DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day).toIso8601String();
    final e = DateTime(end.year, end.month, end.day).toIso8601String();
    return "${userId ?? 0}|$s|$e";
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

  String _fmt(dynamic v) {
    if (v is num) {
      if (v == v.roundToDouble()) return v.toStringAsFixed(0);
      return v.toStringAsFixed(1);
    }
    return "—";
  }
}
