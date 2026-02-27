import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/whoop/whoop_recovery_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/charts/simple_line_chart.dart';
import '../widgets/recovery/recovery_gauge.dart';
import '../widgets/recovery/recovery_metric_card.dart';
import '../widgets/common/date_switcher.dart';

class WhoopRecoveryDetailPage extends StatefulWidget {
  const WhoopRecoveryDetailPage({super.key});

  @override
  State<WhoopRecoveryDetailPage> createState() => _WhoopRecoveryDetailPageState();
}

class _WhoopRecoveryDetailPageState extends State<WhoopRecoveryDetailPage> {
  bool _loading = true;
  Map<DateTime, Map<String, dynamic>> _daily = {};
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRange();
  }

  Future<void> _loadRange() async {
    setState(() => _loading = true);
    try {
      final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final start = day.subtract(const Duration(days: 6));
      final end = day;
      final data = await WhoopRecoveryService().fetchDailyRecovery(
        start: start,
        end: end,
      );
      if (!mounted) return;
      setState(() {
        _daily = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final metrics = _currentMetrics(_daily[dayKey]);
    final headerDate = dayKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recovery"),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(headerDate),
            const SizedBox(height: 12),
            if (metrics.recoveryScore == null && !_loading && _daily.isEmpty) ...[
              _noDataCard(),
            ] else ...[
              Center(child: RecoveryGauge(score: metrics.recoveryScore)),
              const SizedBox(height: 14),
              _metricsGrid(metrics),
            ],
            const SizedBox(height: 16),
            if (metrics.recoveryScore != null || _daily.isNotEmpty || _loading) ...[
              Center(child: _sectionTitle("Recovery Trend (7 Days)")),
              const SizedBox(height: 8),
              _loading && _daily.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            SimpleLineChart(
                              values: _recoverySeries(),
                              color: const Color(0xFFB8E91E),
                              showPoints: true,
                            ),
                            const SizedBox(height: 8),
                            _weekdayLabels(),
                          ],
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noDataCard() {
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
              "No recovery data yet for this day",
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

  List<double?> _recoverySeries() {
    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = day.subtract(const Duration(days: 6));
    final values = <double?>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final dayKey = DateTime(d.year, d.month, d.day);
      final v = _daily[dayKey]?["recovery_score"];
      if (v is num) {
        values.add(v.toDouble());
      } else {
        values.add(null);
      }
    }
    return values;
  }

  Widget _header(DateTime date) {
    final dateLabel = "${_monthName(date.month)} ${date.day}";
    return Center(
      child: Column(
        children: [
          DateSwitcher(
            label: dateLabel,
            onPrev: () => _changeDay(-1),
            onNext: () => _changeDay(1),
            canGoNext: _canGoNext,
          ),
          const SizedBox(height: 6),
          Text(
            "Recovery Details",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _metricsGrid(_RecoveryMetrics metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: "Resting Heart Rate",
                value: _fmt(metrics.rhr),
                unit: "bpm",
                icon: Icons.favorite,
                accent: const Color(0xFFE84C4F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: "HRV (RMSSD)",
                value: _fmt(metrics.hrv),
                unit: "ms",
                icon: Icons.show_chart,
                accent: const Color(0xFF7BD4FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RecoveryMetricCard(
                title: "SpO₂ Level",
                value: _fmt(metrics.spo2),
                unit: "%",
                icon: Icons.water_drop,
                accent: const Color(0xFF35B6FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RecoveryMetricCard(
                title: "Skin Temperature",
                value: _fmt(metrics.skinTemp),
                unit: "°C",
                icon: Icons.thermostat,
                accent: const Color(0xFFFF8A00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  _RecoveryMetrics _currentMetrics(Map<String, dynamic>? today) {
    final recovery = _numFromAny(today?["recovery_score"]);
    final rhr = _numFromAny(today?["rhr"]);
    final hrv = _numFromAny(today?["hrv"]);
    final spo2 = _numFromAny(today?["spo2"]);
    final skin = _numFromAny(today?["skin_temp_c"]);
    final calibrating = today?["user_calibrating"] == true;

    return _RecoveryMetrics(
      recoveryScore: recovery,
      rhr: rhr,
      hrv: hrv,
      spo2: spo2,
      skinTemp: skin,
      calibrating: calibrating,
    );
  }

  String _fmt(double? v) {
    if (v == null) return "—";
    return v.toStringAsFixed(1);
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

  double? _numFromAny(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Widget _weekdayLabels() {
    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final start = day.subtract(const Duration(days: 6));
    final labels = List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return _weekdayName(d.weekday);
    });
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (l) => Text(
              l,
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          )
          .toList(),
    );
  }

  String _weekdayName(int weekday) {
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
}

class _RecoveryMetrics {
  const _RecoveryMetrics({
    required this.recoveryScore,
    required this.rhr,
    required this.hrv,
    required this.spo2,
    required this.skinTemp,
    required this.calibrating,
  });

  final double? recoveryScore;
  final double? rhr;
  final double? hrv;
  final double? spo2;
  final double? skinTemp;
  final bool calibrating;
}
