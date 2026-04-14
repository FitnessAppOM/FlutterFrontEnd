import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/core/daily_provider_push_service.dart';
import '../services/scores/taqa_score_api.dart';
import '../services/training/training_reset_coordinator.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/simple_line_chart.dart';
import '../widgets/common/date_switcher.dart';

class TaqaScoreDetailPage extends StatefulWidget {
  const TaqaScoreDetailPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<TaqaScoreDetailPage> createState() => _TaqaScoreDetailPageState();
}

class _TaqaScoreDetailPageState extends State<TaqaScoreDetailPage> {
  DateTime _selectedDate = DateTime.now();
  TaqaDailyScore? _score;
  bool _loading = true;
  bool _trendLoading = false;
  List<TaqaDailyScore> _trendScores = const [];
  int? _userId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await TrainingResetCoordinator.ensureInitialized();
    final maxDate = _maxSelectableDate();
    if (widget.initialDate != null) {
      final initial = _dateOnly(widget.initialDate!);
      _selectedDate = initial.isAfter(maxDate) ? maxDate : initial;
    } else {
      _selectedDate = maxDate;
    }

    final uid = await AccountStorage.getUserId();
    if (!mounted) return;
    setState(() => _userId = uid);
    if (uid == null) return;
    await Future.wait([_loadScore(uid), _loadTrend(uid)]);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _todayByResetClock() {
    return DailyProviderPushService.effectiveLocalDay();
  }

  DateTime _maxSelectableDate() {
    return _todayByResetClock().subtract(const Duration(days: 1));
  }

  Future<void> _loadScore(int userId) async {
    setState(() => _loading = true);
    final isLiveDate = _dateOnly(_selectedDate) == _maxSelectableDate();
    var result = await TaqaScoreApi.fetchDaily(
      userId: userId,
      date: _selectedDate,
      forceRefresh: isLiveDate,
    );
    if (!isLiveDate && result?.taqaValueScore == null) {
      result = await TaqaScoreApi.fetchDaily(
        userId: userId,
        date: _selectedDate,
        forceRefresh: true,
      );
    }
    if (!mounted) return;
    setState(() {
      _score = result;
      _loading = false;
    });
  }

  Future<void> _loadTrend(int userId) async {
    setState(() => _trendLoading = true);
    final end = _maxSelectableDate();
    final start = end.subtract(const Duration(days: 6));
    final result = await TaqaScoreApi.fetchRange(
      userId: userId,
      start: start,
      end: end,
    );
    if (!mounted) return;
    setState(() {
      _trendScores = result;
      _trendLoading = false;
    });
  }

  void _goToPrevDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    final uid = _userId;
    if (uid != null) _loadScore(uid);
  }

  void _goToNextDay() {
    final yesterday = _maxSelectableDate();
    final next = _selectedDate.add(const Duration(days: 1));
    if (next.isAfter(yesterday)) return;
    _selectedDate = next;
    final uid = _userId;
    if (uid != null) _loadScore(uid);
  }

  bool get _canGoNext {
    final yesterday = _maxSelectableDate();
    final sel = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return sel.isBefore(yesterday);
  }

  String get _locale =>
      Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';

  String t(String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, MMM d', _locale).format(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(
          t("taqa_detail_title"),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.cardDark,
                onRefresh: () async {
                  final uid = _userId;
                  if (uid == null) return;
                  await Future.wait([_loadScore(uid), _loadTrend(uid)]);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    DateSwitcher(
                      label: dateLabel,
                      onPrev: _goToPrevDay,
                      onNext: _goToNextDay,
                      canGoNext: _canGoNext,
                    ),
                    const SizedBox(height: 16),
                    _buildMasterScore(),
                    const SizedBox(height: 20),
                    if (_score != null) ..._buildPillarCards(),
                    if (_score == null) _buildNoData(),
                    const SizedBox(height: 24),
                    _buildTrendSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMasterScore() {
    final score = _score;
    if (score == null || score.taqaValueScore == null) {
      return _buildScoreRing(null, t("taqa_label_taqa_value"), null);
    }
    return _buildScoreRing(
      score.taqaValueScore,
      t("taqa_label_taqa_value"),
      score.provider,
    );
  }

  Widget _buildScoreRing(double? value, String label, String? provider) {
    final display = value == null ? "--" : value.round().toString();
    final progress = value == null ? 0.0 : (value / 100).clamp(0.0, 1.0);
    final ringColor = value == null
        ? Colors.white24
        : _scoreColor(value, inverted: false);

    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(ringColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      display,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (provider != null) ...[
            const SizedBox(height: 8),
            _ProviderBadge(provider: provider),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPillarCards() {
    final s = _score!;
    final cards = <Widget>[];

    cards.add(
      _PillarCard(
        metricKey: 'sleep',
        label: t("taqa_label_sleep"),
        score: s.sleep.score,
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFF9B8CFF),
        path: s.sleep.path,
        details: s.sleep.details,
        detailLabels: {
          'efficiency': t("taqa_detail_efficiency"),
          'architecture_score': t("taqa_detail_architecture"),
          'deep_rem_pct': t("taqa_detail_deep_rem"),
          'disturbance_penalty': t("taqa_detail_disturbance"),
        },
      ),
    );

    cards.add(
      _PillarCard(
        metricKey: 'recovery',
        label: t("taqa_label_recovery"),
        score: s.recovery.score,
        icon: Icons.favorite_rounded,
        color: const Color(0xFF4CD964),
        path: s.recovery.path,
        details: s.recovery.details,
        detailLabels: {
          'hrv_component': t("taqa_detail_hrv"),
          'rhr_component': t("taqa_detail_rhr"),
          'hrv_ratio': 'HRV ratio',
          'rhr_ratio': 'RHR ratio',
          'sleep_component': t("taqa_detail_sleep_comp"),
          'fatigue_component': t("taqa_detail_fatigue"),
        },
      ),
    );

    cards.add(
      _PillarCard(
        metricKey: 'stress',
        label: t("taqa_label_stress"),
        score: s.stress.score,
        icon: Icons.psychology_rounded,
        color: const Color(0xFF4CD964),
        path: s.stress.path,
        details: s.stress.details,
        detailLabels: {
          'hrv_drop_pct': t("taqa_detail_hrv_drop"),
          'rhr_rise_pct': t("taqa_detail_rhr_rise"),
          'sleep_disturbance_pct': t("taqa_detail_sleep_disturb"),
        },
      ),
    );

    cards.add(
      _PillarCard(
        metricKey: 'training_load',
        label: t("taqa_label_training_load"),
        score: s.trainingLoad.score,
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFFFF8A00),
        path: s.trainingLoad.path,
        details: s.trainingLoad.details,
        detailLabels: {
          'today_load': t("taqa_detail_today_load"),
          'chronic_load': t("taqa_detail_chronic"),
          'acute_load': t("taqa_detail_acute"),
          'acwr': t("taqa_detail_ratio"),
          'risk_zone': 'Risk zone',
        },
      ),
    );

    cards.add(
      _PillarCard(
        metricKey: 'nutrition',
        label: t("taqa_label_nutrition"),
        score: s.nutrition.score,
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF00BFA6),
        path: s.nutrition.path,
        details: s.nutrition.details,
        detailLabels: {
          'adherence': t("taqa_detail_adherence"),
          'meal_consistency': t("taqa_detail_meal_consistency"),
          'calories_target': t("taqa_detail_calories_target"),
          'calories_consumed': t("taqa_detail_calories_consumed"),
          'meals_count': t("taqa_detail_meals_logged"),
        },
      ),
    );

    if (s.hasReadiness) {
      cards.add(
        _PillarCard(
          metricKey: 'readiness',
          label: t("taqa_label_readiness"),
          score: s.readiness.score,
          icon: Icons.flash_on_rounded,
          color: const Color(0xFFFFD700),
          path: s.readiness.path,
          details: s.readiness.details,
          detailLabels: {
            'recovery_component': t("taqa_detail_recovery_comp"),
            'sleep_component': t("taqa_detail_sleep_comp"),
            'training_load_component': t("taqa_detail_training_load_comp"),
          },
        ),
      );
    }

    if (s.hasLifestyleBalance) {
      cards.add(
        _PillarCard(
          metricKey: 'lifestyle_balance',
          label: t("taqa_label_lifestyle"),
          score: s.lifestyleBalance.score,
          icon: Icons.balance_rounded,
          color: const Color(0xFF35B6FF),
          path: s.lifestyleBalance.path,
          details: s.lifestyleBalance.details,
          detailLabels: {
            'nutrition_component': t("taqa_detail_nutrition_comp"),
            'steps_score': t("taqa_detail_steps_score"),
            'stress_component': t("taqa_detail_stress_comp"),
            'eq5d_component': 'EQ-5D',
            'phq2_component': 'PHQ-2',
          },
        ),
      );
    }

    final widgets = <Widget>[];
    for (int i = 0; i < cards.length; i++) {
      widgets.add(cards[i]);
      if (i < cards.length - 1) widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _buildNoData() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            _isSelectedYesterday
                ? t("taqa_no_data_yesterday_hint")
                : t("taqa_no_data"),
            style: const TextStyle(color: Colors.white54, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendSection() {
    if (_trendLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_trendScores.isEmpty) return const SizedBox.shrink();

    final values = <double?>[];
    final xLabels = <String>[];
    final end = _maxSelectableDate();
    for (int i = 6; i >= 0; i--) {
      final day = end.subtract(Duration(days: i));
      final dayKey = DateTime(day.year, day.month, day.day);
      xLabels.add(DateFormat('d/M', _locale).format(day));
      final match = _trendScores.where((s) {
        final sd = DateTime(
          s.entryDate.year,
          s.entryDate.month,
          s.entryDate.day,
        );
        return sd == dayKey;
      });
      values.add(match.isNotEmpty ? match.first.taqaValueScore : null);
    }

    final hasData = values.any((v) => v != null);
    if (!hasData) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t("taqa_7day_trend"),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
            ),
          ),
          child: SimpleLineChart(
            values: values,
            color: const Color(0xFF6A5AE0),
            height: 150,
            showPoints: true,
            xLabels: xLabels,
            yLabels: const ['100', '75', '50', '25', '0'],
            yAxisTitle: 'TAQA score',
            xAxisTitle: 'Date',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '7-day TAQA Value trend on a 0-100 scale',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool get _isSelectedYesterday {
    final day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return day == _maxSelectableDate();
  }
}

Color _scoreColor(double score, {bool inverted = false}) {
  final effective = inverted ? (100 - score) : score;
  if (effective >= 75) return const Color(0xFF4CD964);
  if (effective >= 50) return const Color(0xFFFFD700);
  if (effective >= 25) return const Color(0xFFFF8A00);
  return const Color(0xFFFF6B6B);
}

class _ProviderBadge extends StatelessWidget {
  final String provider;
  const _ProviderBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    final label = _providerLabel(provider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'fitbit':
        return 'Fitbit';
      case 'whoop':
        return 'WHOOP';
      case 'google_fit':
        return 'Google Fit';
      case 'samsung':
        return 'Samsung Health';
      case 'healthkit':
        return 'Apple / Samsung Watch';
      default:
        return provider;
    }
  }
}

class _PillarCard extends StatefulWidget {
  final String metricKey;
  final String label;
  final double? score;
  final IconData icon;
  final Color color;
  final String? path;
  final bool inverted;
  final Map<String, dynamic> details;
  final Map<String, String> detailLabels;

  const _PillarCard({
    required this.metricKey,
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
    this.path,
    this.inverted = false,
    required this.details,
    required this.detailLabels,
  });

  @override
  State<_PillarCard> createState() => _PillarCardState();
}

class _PillarCardState extends State<_PillarCard> {
  bool _expanded = false;

  String t(String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    final statusMessage = _statusMessage();
    final hasDetails =
        widget.detailLabels.isNotEmpty && widget.details.isNotEmpty;
    final scoreDisplay = widget.score == null
        ? "--"
        : widget.score!.round().toString();
    final barValue = widget.score == null
        ? 0.0
        : (widget.score! / 100).clamp(0.0, 1.0);
    final barColor = widget.score == null
        ? Colors.white24
        : _scoreColor(widget.score!, inverted: widget.inverted);

    return GestureDetector(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.path != null) ...[
                            const SizedBox(width: 6),
                            _PathChip(path: widget.path!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barValue,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(barColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  scoreDisplay,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hasDetails) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ],
            ),
            if (statusMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  statusMessage,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
            if (_expanded && hasDetails) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              ...widget.detailLabels.entries.map((entry) {
                final rawVal = widget.details[entry.key];
                if (rawVal == null) return const SizedBox.shrink();
                final val = _formatDetailValue(entry.key, rawVal);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        val,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String? _statusMessage() {
    if (widget.metricKey == 'training_load') {
      if (widget.score == null) {
        if (widget.path == 'no_workout') {
          return t("taqa_training_no_workout");
        }
        return t("taqa_training_no_data");
      }
      if (widget.score == 0 && widget.path == 'no_workout') {
        return t("taqa_training_no_workout");
      }
      final note = widget.details['note']?.toString();
      if (note == 'bootstrap_assumed_acwr_1_0') {
        return "Using starter ACWR baseline until enough history is available";
      }
      final riskZone = widget.details['risk_zone']?.toString();
      if (riskZone != null && riskZone.isNotEmpty) {
        return "Load status: ${_prettyRiskZone(riskZone)}";
      }
    }
    if (widget.metricKey == 'nutrition' && widget.score == null) {
      return t("taqa_nutrition_no_data");
    }
    return null;
  }

  String _formatDetailValue(String key, dynamic rawVal) {
    if (key == 'risk_zone') {
      return _prettyRiskZone(rawVal.toString());
    }
    if (rawVal is num) {
      return rawVal.toStringAsFixed(1);
    }
    return rawVal.toString();
  }

  String _prettyRiskZone(String raw) {
    switch (raw) {
      case 'optimal_zone':
        return 'Optimal';
      case 'low_load_warning':
        return 'Low load warning';
      case 'undertraining_flag':
        return 'Undertraining flag';
      case 'moderate_risk':
        return 'Moderate risk';
      case 'injury_risk_flag':
        return 'Injury risk flag';
      default:
        return raw.replaceAll('_', ' ');
    }
  }
}

class _PathChip extends StatelessWidget {
  final String path;
  const _PathChip({required this.path});

  @override
  Widget build(BuildContext context) {
    final label = path == 'wearable'
        ? 'Wearable'
        : path == 'journal'
        ? 'Journal'
        : path == 'diet_data'
        ? 'Diet'
        : path == 'journal_nutrition'
        ? 'Journal'
        : path == 'whoop_direct'
        ? 'WHOOP direct'
        : path == 'fitbit_direct'
        ? 'Fitbit direct'
        : path == 'samsung_direct'
        ? 'Samsung direct'
        : path == 'samsung_direct_inverted'
        ? 'Samsung direct'
        : path == 'prom_aware_composite'
        ? 'Composite'
        : path;
    final icon = path == 'wearable'
        ? Icons.watch_rounded
        : path == 'journal'
        ? Icons.edit_note_rounded
        : path == 'diet_data'
        ? Icons.restaurant_rounded
        : path == 'journal_nutrition'
        ? Icons.edit_note_rounded
        : path == 'whoop_direct'
        ? Icons.bolt_rounded
        : path == 'fitbit_direct'
        ? Icons.bolt_rounded
        : path == 'samsung_direct' || path == 'samsung_direct_inverted'
        ? Icons.bolt_rounded
        : Icons.data_usage_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white38),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
