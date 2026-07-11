import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_pillar_card.dart';
import '../TaqaUI/components/taqa_score_widget.dart' show TaqaOpenArcPainter;
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
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
      // 186px center-to-center spacing (171px card + 15px gap) over the
      // 358px carousel viewport (390 design width minus 16px list padding
      // on each side) puts neighbor cards at x = -77 / 295 around center x = 109.
      viewportFraction: 186 / 358,
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
    if (_previewLoadingKeys.contains(key) ||
        _scorePreviewCache.containsKey(key)) {
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
      appBar: TaqaPageAppBar(
        title: t("taqa_detail_title"),
        backgroundColor: AppColors.appBackground,
        titleColor: TaqaUiColors.charcoal,
        leading: const BackButton(color: TaqaUiColors.charcoal),
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
          final label = DateFormat(
            'EEE, MMM d',
            _locale,
          ).format(day).toUpperCase();
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
                  SizedBox(
                    width: TaqaUiScale.w(62),
                    height: TaqaUiScale.h(10),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                        fontSize: TaqaUiScale.sp(8),
                        fontWeight: FontWeight.w400,
                        color: TaqaUiColors.charcoal,
                        height: 10 / 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ScorePreviewCard(
                    score: dayScore?.taqaValueScore,
                    provider: dayScore?.provider,
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
      TaqaPillarCard(
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
      TaqaPillarCard(
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
      TaqaPillarCard(
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
      TaqaPillarCard(
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
      TaqaPillarCard(
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
        TaqaPillarCard(
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
        TaqaPillarCard(
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

    final arcSize = TaqaUiScale.w(141);
    final visibleHeight = TaqaUiScale.h(124);

    return Container(
      width: TaqaUiScale.w(171),
      height: TaqaUiScale.h(171),
      decoration: BoxDecoration(
        color: TaqaUiColors.unnamedColorE4e93b,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Stack(
        children: [
          Positioned(
            left: TaqaUiScale.w(15),
            top: TaqaUiScale.h(27),
            width: arcSize,
            height: visibleHeight,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: arcSize,
                maxHeight: arcSize,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: arcSize,
                  height: arcSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(arcSize),
                        painter: TaqaOpenArcPainter(progress: progress),
                      ),
                      Transform.translate(
                        offset: Offset(0, -((arcSize - visibleHeight) / 2)),
                        child: Text(
                          '$value',
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(35),
                            fontWeight: FontWeight.w800,
                            color: TaqaUiColors.charcoal,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: TaqaUiScale.w(15),
            top: TaqaUiScale.h(132),
            width: TaqaUiScale.w(141),
            height: TaqaUiScale.h(10),
            child: Text(
              providerText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(8),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.charcoal,
                height: 13 / 8,
              ),
            ),
          ),
        ],
      ),
    );
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

