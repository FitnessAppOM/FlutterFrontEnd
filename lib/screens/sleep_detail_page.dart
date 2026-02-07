import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health/sleep_service.dart';
import '../services/whoop/whoop_sleep_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
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
  DateTime _metricsDate = DateTime.now();
  int _metricsReqId = 0;
  int? _napCount;
  double? _napHours;
  bool _metricsHasData = false;

  static const _sleepGoalKey = "dashboard_sleep_goal";

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _loadRange();
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
          title: const Text("Sleep goal", style: TextStyle(color: Colors.white)),
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

  Future<void> _loadRange() async {
    setState(() => _loading = true);
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
      final data = widget.useWhoop
          ? await _loadWhoopRangeOrLatest(start: start, end: effectiveEnd)
          : await SleepService().fetchDailySleep(start: start, end: effectiveEnd);
      if (!mounted) return;
      setState(() {
        _daily = data;
        _rangeStart = start;
        _rangeEnd = end;
        _loading = false;
      });
      if (widget.useWhoop) {
        await _loadWhoopMetrics();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daily = {};
        _loading = false;
      });
    }
  }

  Future<void> _loadWhoopMetrics() async {
    final requestId = ++_metricsReqId;
    setState(() => _metricsLoading = true);
    try {
      final details = await WhoopSleepService().fetchSleepDayDetails(_metricsDate);
      if (!mounted) return;
      if (requestId != _metricsReqId) return;
      final sleep = details?["sleep"];
      final metrics =
          sleep is Map<String, dynamic> ? _WhoopSleepMetrics.fromSleep(sleep) : null;
      final napCount = details?["nap_count"];
      final napHours = details?["nap_hours"];
      final hasData = metrics != null;
      setState(() {
        _whoopMetrics = metrics;
        _napCount = napCount is num ? napCount.round() : int.tryParse("$napCount");
        _napHours = napHours is num ? napHours.toDouble() : double.tryParse("$napHours");
        _metricsHasData = hasData;
        _metricsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (requestId != _metricsReqId) return;
      setState(() {
        _whoopMetrics = null;
        _napCount = null;
        _napHours = null;
        _metricsHasData = false;
        _metricsLoading = false;
      });
    }
  }

  Future<Map<DateTime, double>> _loadWhoopRangeOrLatest({
    required DateTime start,
    required DateTime end,
  }) async {
    final range = await WhoopSleepService().fetchDailySleep(start: start, end: end);
    if (range.isNotEmpty) return range;
    return WhoopSleepService().fetchLatestSleepDaily();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final theme = Theme.of(context);
    final totalHours = _daily.values.fold<double>(0, (a, b) => a + b);
    final avgHours = _daily.isEmpty ? 0 : totalHours / _daily.length;
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
                labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                    _buildMetricsTab(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendsTab(String Function(String) t, ThemeData theme, Widget bars) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                side: BorderSide(color: AppColors.accent.withValues(alpha: 0.7)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t("sleep_goal_btn").replaceAll("{value}", (_goal ?? 8.0).toStringAsFixed(1)),
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
          actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    if (m == null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricsDateHeader(),
          ],
        ),
      );
    }
    final sleepHours = (m.sleepTimeMs / 3600000.0);
    final bedHours = (m.totalInBedMs / 3600000.0);
    final efficiency = m.efficiency;
    final stage = m.stagePercentages;

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
                  value: isLoading ? "…" : _formatHours(sleepHours),
                  subtitle: "Light + Deep + REM",
                  accentColor: const Color(0xFF9B8CFF),
                  icon: Icons.nights_stay,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SleepMetricTile(
                  title: "Time in bed",
                  value: isLoading ? "…" : _formatHours(bedHours),
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
            value: isLoading ? "…" : "${(efficiency * 100).toStringAsFixed(0)}%",
            subtitle: "Sleep time / time in bed",
            accentColor: const Color(0xFF00BFA6),
            icon: Icons.speed,
            child: SleepProgressBar(value: isLoading ? 0 : efficiency),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SleepMetricTile(
                  title: "Disturbances",
                  value: isLoading ? "…" : m.disturbances.toString(),
                  subtitle: "Night disruptions",
                  accentColor: const Color(0xFFFF8A00),
                  icon: Icons.bolt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SleepMetricTile(
                  title: "Sleep cycles",
                  value: isLoading ? "…" : m.cycles.toString(),
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
            value: isLoading
                ? "…"
                : (napCount == null ? "—" : "$napCount nap${napCount == 1 ? '' : 's'}"),
            subtitle: isLoading
                ? ""
                : (napHours == null ? "Total —" : "Total ${_formatHours(napHours)}"),
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
                  lightPct: isLoading ? 0 : (stage["light"] ?? 0),
                  deepPct: isLoading ? 0 : (stage["slow_wave"] ?? 0),
                  remPct: isLoading ? 0 : (stage["rem"] ?? 0),
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
                        value: isLoading
                            ? "…"
                            : "${((stage["light"] ?? 0) * 100).toStringAsFixed(0)}%",
                      ),
                      const SizedBox(height: 6),
                      _stageLegend(
                        color: const Color(0xFF9B8CFF),
                        label: "Deep",
                        value: isLoading
                            ? "…"
                            : "${((stage["slow_wave"] ?? 0) * 100).toStringAsFixed(0)}%",
                      ),
                      const SizedBox(height: 6),
                      _stageLegend(
                        color: const Color(0xFF00BFA6),
                        label: "REM",
                        value: isLoading
                            ? "…"
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

  Widget _metricsDateHeader() {
    final dateLabel = "${_monthName(_metricsDate.month)} ${_metricsDate.day}";
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selected = DateTime(_metricsDate.year, _metricsDate.month, _metricsDate.day);
    final canGoNext = selected.isBefore(todayOnly);
    return DateSwitcher(
      label: dateLabel,
      onPrev: () => _changeMetricsDate(-1),
      onNext: () => _changeMetricsDate(1),
      canGoNext: canGoNext,
    );
  }

  void _changeMetricsDate(int delta) {
    final next = DateTime(_metricsDate.year, _metricsDate.month, _metricsDate.day + delta);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return;
    setState(() => _metricsDate = next);
    _loadWhoopMetrics();
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white70),
        ),
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
            child: Icon(
              loading ? Icons.hourglass_bottom : Icons.info_outline,
              color: const Color(0xFF2D7CFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading ? "Loading sleep metrics..." : "No sleep metrics for this day",
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
        setState(() => _range = value);
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
    const labelHeight = 20.0;

    final isMonthly = _range == 'monthly';
    final barSpacing = isMonthly ? 2.0 : 4.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barMaxHeight = constraints.maxHeight - labelHeight;

          final barAreaWidth =
              (constraints.maxWidth - yAxisWidth - yAxisGap).clamp(0.0, double.infinity);
          final barSlot = isMonthly
              ? (barAreaWidth / (entries.isEmpty ? 1 : entries.length))
              : null;
          final barWidth = isMonthly ? (barSlot! - (barSpacing * 2)).clamp(0.0, double.infinity) : null;

          final barWidgets = entries.map((e) {
            // Use actual max for accurate bar heights
            final heightFactor = (e.value / actualMax).clamp(0.0, 1.0);
            final label = e.key;
            final bar = Container(
              height: barMaxHeight * heightFactor,
              width: barWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFF35B6FF),
                    Color(0xFF9B8CFF),
                  ],
                ),
              ),
            );

            final content = Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar,
                if (label.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );

            if (isMonthly) {
              return SizedBox(
                width: barSlot,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: barSpacing),
                  child: content,
                ),
              );
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: barSpacing),
                child: content,
              ),
            );
          }).toList();

          final yAxis = SizedBox(
            width: yAxisWidth,
            height: barMaxHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatHoursLabel(actualMax),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatHoursLabel(midVal),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatHoursLabel(0),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              yAxis,
              const SizedBox(width: yAxisGap),
              Expanded(
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: barWidgets,
                  ),
                ),
              ),
            ],
          );
        },
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
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
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
  List<MapEntry<String, double>> _prepareEntries() {
    if (_daily.isEmpty) return [];
    if (_range != 'yearly') {
      final start = _rangeStart;
      final end = _rangeEnd;
      if (start == null || end == null) {
        final entries = _daily.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return entries
            .map((e) => MapEntry("", e.value))
            .toList();
      }
      final items = <MapEntry<String, double>>[];
      var cursor = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      while (!cursor.isAfter(last)) {
        final key = DateTime(cursor.year, cursor.month, cursor.day);
        items.add(MapEntry("", _daily[key] ?? 0));
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

    final entries = <MapEntry<String, double>>[];
    var cursor = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(last)) {
      final key = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
      final values = buckets[key] ?? const <double>[];
      final avg = values.isEmpty
          ? 0.0
          : values.reduce((a, b) => a + b) / values.length;
      entries.add(const MapEntry("", 0)); // placeholder, replaced below
      entries[entries.length - 1] = MapEntry("", avg.toDouble());
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return entries;
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
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
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
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text("Add sleep hours", style: TextStyle(color: Colors.white)),
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

    if (result != null) {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await SleepService().saveManualEntry(day, result);
      if (mounted) {
        _loadRange();
      }
    }
  }

  double _todaySleepHours() {
    final today = DateTime.now();
    final dayKey = DateTime(today.year, today.month, today.day);
    return _daily[dayKey] ?? 0;
  }
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
