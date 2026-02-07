import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/whoop/whoop_cycle_service.dart';
import '../widgets/recovery/recovery_metric_card.dart';
import '../widgets/charts/simple_line_chart.dart';
import '../widgets/common/date_switcher.dart';

class WhoopCycleDetailPage extends StatefulWidget {
  const WhoopCycleDetailPage({super.key});

  @override
  State<WhoopCycleDetailPage> createState() => _WhoopCycleDetailPageState();
}

class _WhoopCycleDetailPageState extends State<WhoopCycleDetailPage> {
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  Map<DateTime, Map<String, dynamic>> _daily = {};
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _loadRange();
  }

  Future<void> _loadRange() async {
    final requestId = ++_reqId;
    setState(() => _loading = true);
    try {
      final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final start = day.subtract(const Duration(days: 6));
      final end = day;
      final data = await WhoopCycleService().fetchDailyCycles(start: start, end: end);
      if (!mounted) return;
      if (requestId != _reqId) return;
      setState(() {
        _daily = data;
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
    final dayKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final metrics = _daily[dayKey];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Cycle"),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(dayKey),
            const SizedBox(height: 14),
            _metricsGrid(metrics, isLoading: _loading),
            if (!_hideTrendForNoData(metrics)) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Average HR Trend (7 Days)",
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

  Widget _metricsGrid(Map<String, dynamic>? metrics, {required bool isLoading}) {
    if (metrics == null && isLoading) {
      return const SizedBox.shrink();
    }
    if (metrics == null && !isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
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
                "No cycle data yet for this day",
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

    if (metrics == null && isLoading) {
      return Column(
        children: [
          Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: "Strain",
                value: isLoading ? "…" : _fmt(metrics?["strain"]),
                unit: "",
                icon: Icons.bolt,
                accent: const Color(0xFFFF8A00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: "Avg HR",
                value: isLoading ? "…" : _fmt(metrics?["avg_hr"]),
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
                title: "Max HR",
                value: isLoading ? "…" : _fmt(metrics?["max_hr"]),
                unit: "bpm",
                icon: Icons.show_chart,
                accent: const Color(0xFF7BD4FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: "Energy",
                value: isLoading ? "…" : _fmt(metrics?["kilojoules"]),
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: "Strain",
                value: _fmt(metrics?["strain"]),
                unit: "",
                icon: Icons.bolt,
                accent: const Color(0xFFFF8A00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: "Avg HR",
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
                title: "Max HR",
                value: _fmt(metrics?["max_hr"]),
                unit: "bpm",
                icon: Icons.show_chart,
                accent: const Color(0xFF7BD4FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: "Energy",
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

  bool _hideTrendForNoData(Map<String, dynamic>? metrics) {
    return metrics == null;
  }

  List<double?> _avgHrSeries() {
    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = day.subtract(const Duration(days: 6));
    final values = <double?>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final dayKey = DateTime(d.year, d.month, d.day);
      final v = _daily[dayKey]?["avg_hr"];
      if (v is num) {
        values.add(v.toDouble());
      } else {
        values.add(null);
      }
    }
    return values;
  }

  Widget _avgHrNote() {
    final dayKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final yesterdayKey = dayKey.subtract(const Duration(days: 1));
    final today = _daily[dayKey]?["avg_hr"];
    final yesterday = _daily[yesterdayKey]?["avg_hr"];
    if (today is! num || yesterday is! num) {
      return const SizedBox.shrink();
    }
    final delta = (today.toDouble() - yesterday.toDouble());
    final up = delta >= 0;
    final text = up
        ? "Avg HR up by ${delta.toStringAsFixed(1)} bpm vs yesterday"
        : "Avg HR down by ${delta.abs().toStringAsFixed(1)} bpm vs yesterday";
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
    final next = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + delta);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return;
    setState(() => _selectedDate = next);
    _loadRange();
  }

  bool get _canGoNext {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isBefore(todayOnly);
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
