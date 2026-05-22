import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/styles/taqa_ui_styles.dart';
import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/core/daily_provider_push_service.dart';
import '../services/scores/taqa_score_api.dart';
import '../services/training/training_reset_coordinator.dart';
import '../theme/app_theme.dart';

class TaqaScoreDetailPage extends StatefulWidget {
  const TaqaScoreDetailPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<TaqaScoreDetailPage> createState() => _TaqaScoreDetailPageState();
}

class _TaqaScoreDetailPageState extends State<TaqaScoreDetailPage> {
  static const int _previewYearsBack = 5;

  DateTime _selectedDate = DateTime.now();
  TaqaDailyScore? _score;
  bool _loading = true;
  int? _userId;
  int _scoreReqId = 0;
  late final PageController _scorePreviewController;
  DateTime? _maxSelectableDateAnchor;
  final Map<String, TaqaDailyScore?> _scorePreviewCache = {};
  final Set<String> _previewLoadingKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _scorePreviewController = PageController(
      initialPage: _previewIndexForDate(_selectedDate),
      viewportFraction: 0.58,
    );
    AccountStorage.accountChange.addListener(_onAccountChanged);
    _init();
  }

  Future<void> _init() async {
    await TrainingResetCoordinator.ensureInitialized();
    _maxSelectableDateAnchor = _dateOnly(_computeMaxSelectableDate());
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPreviewToSelectedDate();
    });
    if (uid == null) return;
    await _loadScore(uid);
  }

  void _onAccountChanged() {
    TaqaScoreApi.clearCache();
    _reloadForActiveAccount();
  }

  Future<void> _reloadForActiveAccount() async {
    final uid = await AccountStorage.getUserId();
    if (!mounted) return;
    _scoreReqId++;
    setState(() {
      _userId = uid;
      _score = null;
      _loading = uid != null && uid > 0;
    });
    if (uid == null || uid <= 0) {
      return;
    }
    await _loadScore(uid);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dayKey(DateTime date) {
    final d = _dateOnly(date);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _sameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);
  DateTime _todayByResetClock() {
    return DailyProviderPushService.effectiveLocalDay();
  }

  DateTime _computeMaxSelectableDate() {
    return _todayByResetClock().subtract(const Duration(days: 1));
  }

  DateTime _maxSelectableDate() {
    return _maxSelectableDateAnchor ?? _computeMaxSelectableDate();
  }

  DateTime _previewStartDate() {
    return _maxSelectableDate().subtract(
      const Duration(days: 365 * _previewYearsBack),
    );
  }

  int _previewItemCount() {
    return _maxSelectableDate().difference(_previewStartDate()).inDays + 1;
  }

  DateTime _previewDateForIndex(int index) {
    final safeIndex = index.clamp(0, _previewItemCount() - 1);
    return _previewStartDate().add(Duration(days: safeIndex));
  }

  int _previewIndexForDate(DateTime date) {
    final days = _dateOnly(date).difference(_previewStartDate()).inDays;
    return days.clamp(0, _previewItemCount() - 1);
  }

  void _syncPreviewToSelectedDate() {
    if (!_scorePreviewController.hasClients) return;
    final target = _previewIndexForDate(_selectedDate);
    final current = _scorePreviewController.page?.round();
    if (current == target) return;
    _scorePreviewController.jumpToPage(target);
  }

  Future<void> _loadScore(int userId) async {
    final reqId = ++_scoreReqId;
    final selectedDate = _dateOnly(_selectedDate);
    final selectedKey = _dayKey(selectedDate);
    setState(() {
      _loading = true;
      if (_scorePreviewCache.containsKey(selectedKey)) {
        _score = _scorePreviewCache[selectedKey];
      }
    });
    final isLiveDate = selectedDate == _maxSelectableDate();
    var result = await TaqaScoreApi.fetchDaily(
      userId: userId,
      date: selectedDate,
      forceRefresh: isLiveDate,
    );
    if (!isLiveDate && result?.taqaValueScore == null) {
      result = await TaqaScoreApi.fetchDaily(
        userId: userId,
        date: selectedDate,
        forceRefresh: true,
      );
    }
    if (!mounted) return;
    if (reqId != _scoreReqId) return;
    if (_dateOnly(_selectedDate) != selectedDate) return;
    final currentUserId = await AccountStorage.getUserId();
    if (currentUserId != userId) return;
    if (result != null && result.userId != userId) return;
    setState(() {
      _score = result;
      _loading = false;
      _scorePreviewCache[_dayKey(selectedDate)] = result;
    });
    _prefetchAdjacentScores(userId);
  }

  Future<void> _prefetchAdjacentScores(int userId) async {
    final prev = _selectedDate.subtract(const Duration(days: 1));
    await _prefetchScoreForDate(userId, prev);
    final next = _selectedDate.add(const Duration(days: 1));
    if (!next.isAfter(_maxSelectableDate())) {
      await _prefetchScoreForDate(userId, next);
    }
  }

  Future<void> _prefetchScoreForDate(int userId, DateTime date) async {
    final day = _dateOnly(date);
    if (day.isAfter(_maxSelectableDate())) return;
    final key = _dayKey(day);
    if (_previewLoadingKeys.contains(key) || _scorePreviewCache.containsKey(key)) {
      return;
    }
    _previewLoadingKeys.add(key);
    try {
      final isLiveDate = day == _maxSelectableDate();
      var result = await TaqaScoreApi.fetchDaily(
        userId: userId,
        date: day,
        forceRefresh: isLiveDate,
      );
      if (!isLiveDate && result?.taqaValueScore == null) {
        result = await TaqaScoreApi.fetchDaily(
          userId: userId,
          date: day,
          forceRefresh: true,
        );
      }
      if (!mounted) return;
      setState(() {
        _scorePreviewCache[key] = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scorePreviewCache[key] = null;
      });
    } finally {
      _previewLoadingKeys.remove(key);
    }
  }

  TaqaDailyScore? _scoreForPreviewDay(DateTime date) {
    if (_sameDay(date, _selectedDate)) return _score;
    return _scorePreviewCache[_dayKey(date)];
  }

  @override
  void dispose() {
    AccountStorage.accountChange.removeListener(_onAccountChanged);
    _scorePreviewController.dispose();
    super.dispose();
  }

  String get _locale =>
      Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';

  String t(String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        title: Text(
          t("taqa_detail_title"),
          style: TaqaUiStyles.pageTitle.copyWith(
            color: TaqaUiColors.charcoal,
          ),
        ),
        leading: const BackButton(color: TaqaUiColors.charcoal),
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading && _score == null && _scorePreviewCache.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.cardDark,
                onRefresh: () async {
                  final uid = _userId;
                  if (uid == null) return;
                  await _loadScore(uid);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    _buildScorePreviewCarousel(),
                    const SizedBox(height: 20),
                    if (_score != null) ..._buildPillarCards(),
                    if (_score == null) _buildNoData(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildScorePreviewCarousel() {
    final currentIndex = _previewIndexForDate(_selectedDate);

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _scorePreviewController,
        onPageChanged: (index) async {
          final day = _previewDateForIndex(index);
          if (_sameDay(day, _selectedDate)) return;
          final key = _dayKey(day);
          setState(() {
            _selectedDate = day;
            if (_scorePreviewCache.containsKey(key)) {
              _score = _scorePreviewCache[key];
            }
          });
          final uid = _userId;
          if (uid != null) {
            await _loadScore(uid);
          }
        },
        itemCount: _previewItemCount(),
        itemBuilder: (context, index) {
          final day = _previewDateForIndex(index);
          final isCenter = index == currentIndex;
          final dayScore = _scoreForPreviewDay(day);
          final label = DateFormat('EEE, MMM d', _locale).format(day).toUpperCase();
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              8,
              isCenter ? 2 : 14,
              8,
              isCenter ? 2 : 14,
            ),
            child: Opacity(
              opacity: isCenter ? 1 : 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _ScorePreviewCard(
                      score: dayScore?.taqaValueScore,
                      provider: dayScore?.provider,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
          'phase_label': 'Phase',
          'badge_label': 'Badge',
          'tflu_today': 'Today Load',
          'tflu_7d_avg': '7-Day Avg Load',
          'tflu_28d_avg': '28-Day Avg Load',
          'normalization_peak': 'Normalization Peak',
          'training_minutes': 'Training Minutes',
          'rest_minutes': 'Rest Minutes',
          'daily_volume_score': 'Daily Volume Score',
          'raw_load': 'Raw Load',
          'vbp_score': 'VBP Efficiency',
          'consistency_score': 'Session Consistency',
          'wow_score': 'WoW Progression',
          'efficiency_ratio': 'Efficiency Ratio',
          'active_days_7d': 'Active Days (7d)',
          'wow_change_pct': 'WoW Change',
          'risk_zone': 'Risk Zone',
          'status_label': 'Status',
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

  bool get _isSelectedYesterday {
    final day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return day == _maxSelectableDate();
  }
}

class _ScorePreviewCard extends StatelessWidget {
  const _ScorePreviewCard({this.score, this.provider});

  final double? score;
  final String? provider;

  @override
  Widget build(BuildContext context) {
    final value = score?.round() ?? 0;
    final progress = score == null ? 0.0 : (score! / 100).clamp(0.0, 1.0);
    final providerText = _providerLabel(provider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TaqaUiColors.unnamedColorE4e93b,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 134,
              height: 134,
              child: CustomPaint(
                painter: _PreviewArcPainter(progress: progress),
              ),
            ),
          ),
          Center(
            child: Text(
              '$value',
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: 35,
                fontWeight: FontWeight.w800,
                color: TaqaUiColors.charcoal,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 19,
            child: Text(
              providerText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.charcoal,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewArcPainter extends CustomPainter {
  const _PreviewArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = TaqaUiColors.charcoal.withValues(alpha: 0.14);

    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = TaqaUiColors.charcoal.withValues(alpha: 0.3);

    const start = 3 * math.pi / 4;
    const sweep = 3 * math.pi / 2;
    canvas.drawArc(rect, start, sweep, false, base);
    if (progress > 0) {
      canvas.drawArc(rect, start, sweep * progress, false, value);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

String _providerLabel(String? provider) {
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
      return 'Smart Watch';
    case null:
      return 'Smart Watch';
    default:
      return provider;
  }
}

class _PillarCard extends StatefulWidget {
  final String metricKey;
  final String label;
  final double? score;
  final IconData icon;
  final Color color;
  final String? path;
  final Map<String, dynamic> details;
  final Map<String, String> detailLabels;

  const _PillarCard({
    required this.metricKey,
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
    this.path,
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
    final isDarkCard =
        widget.metricKey == 'training_load' ||
        widget.metricKey == 'nutrition' ||
        widget.metricKey == 'readiness' ||
        widget.metricKey == 'lifestyle_balance';
    final hasDetails =
        widget.detailLabels.isNotEmpty && widget.details.isNotEmpty;
    final scoreDisplay = widget.score == null
        ? "--"
        : widget.score!.round().toString();
    final barValue = widget.score == null
        ? 0.0
        : (widget.score! / 100).clamp(0.0, 1.0);
    final cardBg = isDarkCard ? TaqaUiColors.charcoal : TaqaUiColors.white;
    final textColor = isDarkCard ? TaqaUiColors.white : TaqaUiColors.charcoal;
    final chipBorder = isDarkCard
        ? TaqaUiColors.lightGray.withValues(alpha: 0.6)
        : TaqaUiColors.graphite.withValues(alpha: 0.6);
    final barTrack = isDarkCard
        ? TaqaUiColors.graphite.withValues(alpha: 0.95)
        : TaqaUiColors.lightGray.withValues(alpha: 0.9);
    final barFill = isDarkCard
        ? TaqaUiColors.lightGray.withValues(alpha: 0.85)
        : TaqaUiColors.graphite.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                if (widget.path != null)
                  _PathChip(
                    path: widget.path!,
                    isDark: isDarkCard,
                    borderColor: chipBorder,
                  ),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: barValue,
                      backgroundColor: barTrack,
                      valueColor: AlwaysStoppedAnimation(barFill),
                      minHeight: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  scoreDisplay,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                if (hasDetails) ...[
                  const SizedBox(width: 2),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDarkCard
                        ? TaqaUiColors.white.withValues(alpha: 0.85)
                        : TaqaUiColors.charcoal.withValues(alpha: 0.85),
                    size: 18,
                  ),
                ],
              ],
            ),
            if (_expanded && hasDetails) ...[
              if (_statusMessage() != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _statusMessage()!,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: textColor.withValues(alpha: 0.78),
                      letterSpacing: 0,
                      height: 25 / 15,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Divider(
                color: isDarkCard
                    ? TaqaUiColors.lightGray.withValues(alpha: 0.25)
                    : TaqaUiColors.graphite.withValues(alpha: 0.2),
                height: 1,
              ),
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
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.72),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        val,
                        style: TextStyle(
                          color: textColor,
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
      final note = widget.details['note']?.toString();
      if (note != null && note.isNotEmpty) return note;

      if (widget.path == 'coming_soon') {
        return 'Training Load support for this provider is coming soon.';
      }

      if (widget.score == null) {
        final phaseLabel = widget.details['phase_label']?.toString();
        if (phaseLabel == 'Calibrating') {
          final remaining = widget.details['progress_remaining'];
          final unit = widget.details['progress_unit']?.toString() ?? 'days';
          if (remaining is num) {
            return '$remaining more $unit needed to unlock Training Load.';
          }
          return 'Training Load is calibrating.';
        }
        return t("taqa_training_no_data");
      }

      final status = widget.details['status_label']?.toString();
      if (status != null && status.isNotEmpty) {
        return 'Load status: $status';
      }
    }
    if (widget.metricKey == 'nutrition' && widget.score == null) {
      return t("taqa_nutrition_no_data");
    }
    return null;
  }

  String _formatDetailValue(String key, dynamic rawVal) {
    if (rawVal is bool) {
      return rawVal ? 'Yes' : 'No';
    }
    if (rawVal is num) {
      if (key == 'active_days_7d' || key == 'phase') {
        return rawVal.toInt().toString();
      }
      if (key == 'wow_change_pct') {
        return '${rawVal.toStringAsFixed(1)}%';
      }
      if (key == 'efficiency_ratio') {
        return rawVal.toStringAsFixed(3);
      }
      return rawVal.toStringAsFixed(1);
    }
    return rawVal.toString();
  }
}

class _PathChip extends StatelessWidget {
  final String path;
  final bool isDark;
  final Color borderColor;
  const _PathChip({
    required this.path,
    required this.isDark,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isWhoop = path == 'whoop_direct';
    final isFitbit = path == 'fitbit_direct';
    final label = path == 'wearable'
        ? 'WEARABLE'
        : path == 'journal'
        ? 'JOURNAL'
        : path == 'tflu_v1'
        ? 'TFLU'
        : path == 'coming_soon'
        ? 'COMING SOON'
        : path == 'diet_data'
        ? 'DIET'
        : path == 'journal_nutrition'
        ? 'JOURNAL'
        : path == 'whoop_direct'
        ? 'WHOOP DIRECT'
        : path == 'fitbit_direct'
        ? 'FITBIT DIRECT'
        : path == 'samsung_direct'
        ? 'SAMSUNG DIRECT'
        : path == 'samsung_direct_inverted'
        ? 'SAMSUNG DIRECT'
        : path == 'prom_aware_composite'
        ? 'COMPOSITE'
        : path.toUpperCase();
    final chipTextColor = isDark
        ? TaqaUiColors.white
        : TaqaUiColors.unnamedColor1c1d17;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? TaqaUiColors.charcoal : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWhoop || isFitbit) ...[
            Image.asset(
              isWhoop ? 'assets/images/whoop.png' : 'assets/images/fitbit.png',
              width: 10,
              height: 10,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              color: chipTextColor,
              fontSize: 8,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
