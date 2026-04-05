import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';
import '../../widgets/news_carousel.dart';
import '../../screens/announcements_page.dart';
import '../../services/news/news_service.dart';
import '../../services/news/news_tag_actions.dart';
import '../../models/news_item.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/dashboard/progress_meter.dart';
import '../../widgets/dashboard/bar_trend.dart';
import '../../widgets/dashboard/whoop_recovery_card.dart';
import '../../widgets/dashboard/whoop_sleep_card.dart';
import '../../widgets/dashboard/whoop_extras_card.dart';
import '../../widgets/dashboard/whoop_cycle_card.dart';
import '../../widgets/dashboard/whoop_body_card.dart';
import '../../widgets/dashboard/body_measurements_card.dart';
import '../../widgets/dashboard/body_measurements_sheet.dart';
import '../../widgets/dashboard/water_intake_card.dart';
import '../../widgets/dashboard/water_intake_sheet.dart';
import '../../widgets/dashboard/fitbit_daily_activity_card.dart';
import '../../widgets/dashboard/fitbit_daily_activity_sheet.dart';
import '../../widgets/dashboard/fitbit_heart_card.dart';
import '../../widgets/dashboard/fitbit_heart_sheet.dart';
import '../../widgets/dashboard/fitbit_sleep_card.dart';
import '../../widgets/dashboard/fitbit_sleep_sheet.dart';
import '../../widgets/dashboard/fitbit_vitals_card.dart';
import '../../widgets/dashboard/fitbit_vitals_sheet.dart';
import '../../widgets/dashboard/fitbit_body_card.dart';
import '../../widgets/dashboard/fitbit_body_sheet.dart';
import '../../widgets/dashboard/fitbit_extras_card.dart';
import '../../widgets/dashboard/health_recovery_load_card.dart';
import '../../widgets/dashboard/health_recovery_load_sheet.dart';
import '../../widgets/dashboard/diet_progress_card.dart';
import '../../widgets/dashboard/taqa_score_widget.dart';
import '../../widgets/dashboard/edit_mode_bubble.dart';
import '../../widgets/dashboard/widget_library_sheet.dart';
import '../../screens/whoop_insights_page.dart';
import '../../screens/fitbit_insights_page.dart';
import '../../screens/strava_detail_page.dart';
import '../../screens/whoop_recovery_detail_page.dart';
import '../../screens/whoop_cycle_detail_page.dart';
import '../../screens/whoop_body_detail_page.dart';
import '../../theme/app_theme.dart';
import '../../core/account_storage.dart';
import '../../services/auth/profile_service.dart';
import '../../services/metrics/daily_metrics_api.dart';
import '../../services/core/daily_provider_push_service.dart';
import '../../services/scores/taqa_score_api.dart';
import '../../config/base_url.dart';
import '../../services/health/steps_service.dart';
import '../../services/health/sleep_service.dart';
import '../../services/health/health_recovery_load_service.dart';
import '../../services/whoop/whoop_sleep_service.dart';
import '../../services/whoop/whoop_widget_data_service.dart';
import '../../services/diet/calories_service.dart';
import '../../services/diet/diet_day_summary_storage.dart';
import '../../services/diet/diet_service.dart';
import '../../services/health/water_service.dart';
import '../../services/fitbit/fitbit_activity_service.dart';
import '../../services/fitbit/fitbit_heart_service.dart';
import '../../services/fitbit/fitbit_sleep_service.dart';
import '../../services/fitbit/fitbit_vitals_service.dart';
import '../../services/fitbit/fitbit_body_service.dart';
import '../../services/fitbit/fitbit_summary_service.dart';
import '../../services/fitbit/fitbit_db_service.dart';
import '../../services/strava/strava_service.dart';
import '../../screens/sleep_detail_page.dart';
import '../../screens/steps_detail_page.dart';
import '../../screens/calories_detail_page.dart';
import '../../screens/daily_journal.dart';
import '../../screens/taqa_score_detail_page.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common/date_header.dart';
import '../../widgets/confirm_dialog.dart';
import '../../services/training/training_service.dart';
import '../../services/training/training_calories_service.dart';
import '../../services/training/training_progress_storage.dart';
import '../../services/training/training_calendar_service.dart';
import '../../services/training/training_reset_coordinator.dart';
import '../../widgets/primary_button.dart';
import '../../screens/whoop_test_page.dart';
import '../../widgets/release_notes_notice.dart';
import '../../services/metrics/daily_journal_service.dart';
import '../../services/core/navigation_service.dart';
import 'dart:math' as math;

class _NextTrainingDayResult {
  final String? label;
  final bool allDone;
  const _NextTrainingDayResult({this.label, this.allDone = false});
}

class _LocalTrainingProgress {
  final int completed;
  final int total;
  const _LocalTrainingProgress({required this.completed, required this.total});
}

class _ExerciseProgressSnapshot {
  final int? total;
  final int? completed;
  final String? nextLabel;
  final bool nextAllDone;
  final String? programMode;

  const _ExerciseProgressSnapshot({
    required this.total,
    required this.completed,
    required this.nextLabel,
    required this.nextAllDone,
    required this.programMode,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  static const int _journalResetHour = 6;
  static const String _journalPromptShownKey =
      "daily_journal_prompt_shown_date_6am";

  String _journalPromptShownKeyForUser(int userId) =>
      "${_journalPromptShownKey}_u$userId";
  static const List<String> _defaultStatOrder = [
    'steps',
    'sleep',
    'water',
    'calories',
  ];
  static const Set<String> _allowedStatKeys = {
    'steps',
    'sleep',
    'water',
    'calories',
    'body',
    'health_recovery_load',
    'fitbit_activity',
    'fitbit_heart',
    'fitbit_sleep',
    'fitbit_vitals',
    'fitbit_body',
    'whoop_sleep',
    'whoop_recovery',
    'whoop_cycle',
    'whoop_body',
    'strava_activities',
  };
  static final Map<String, List<double>> _trendSleepWeekCache = {};
  static final Map<String, List<double>> _trendCaloriesWeekCache = {};
  final Map<DateTime, Map<String, dynamic>> _dietSummaryCache = {};
  final Map<DateTime, _ExerciseProgressSnapshot> _exerciseProgressCache = {};
  AnimationController? _wiggleController;
  Animation<double>? _wiggleAnim;
  bool _wiggling = false;
  final List<String> _statOrder = List<String>.from(_defaultStatOrder);
  int? _statOrderUserId;
  final Map<String, GlobalKey> _tileKeys = {};
  OverlayEntry? _dragOverlay;
  String? _dragKey;
  Offset? _dragTouchOffset;
  Size? _dragSize;
  Offset? _dragTopLeft;
  Offset? _lastDragPos;
  Offset? _dragStartPos;
  String? _lastSwapTarget;
  Widget? _dragChild;

  List<NewsItem> _news = const [];
  bool _loading = true;
  String? _error;
  final _mockSteps = [8200, 9100, 10400, 7600, 8800, 9900, 11200];
  final _mockSleepHours = [6.5, 7.0, 7.2, 6.8, 7.5, 7.8, 8.0];
  String? _avatarUrl;
  String? _avatarPath;
  String? _displayName;
  double? _heightCm;
  double? _weightKg;
  int? _todaySteps;
  int? _stepsGoal;
  bool _stepsLoading = false;
  double? _sleepHours;
  double? _sleepGoal;
  bool _sleepLoading = false;
  int? _todayCalories;
  int? _caloriesGoal;
  bool _caloriesLoading = false;
  double? _waterGoal;
  double? _waterIntake;
  bool _waterLoading = false;
  int? _stepsDelta;
  int? _sleepDelta;
  int? _caloriesDelta;
  int? _waterDelta;
  int? _weeklySteps;
  bool _weeklyStepsLoading = false;
  bool _wearableBubbleVisible = false;
  String? _wearableBubbleType;
  List<double> _trendSleep = const [];
  List<double> _trendCalories = const [];
  bool _trendSleepLoading = false;
  bool _trendCaloriesLoading = false;
  bool _trendSyncRefreshInFlight = false;
  int _trendSleepReqId = 0;
  int _trendCaloriesReqId = 0;
  DateTime? _trendWeekStart;
  DateTime? _trendCaloriesLoadedWeekStart;
  String? _trendSleepSourceKey;
  String? _activeTrendSleepCacheKey;
  String? _activeTrendCaloriesCacheKey;

  String _trendDateToken(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  String _trendSleepCacheKey({
    required int userId,
    required String sourceKey,
    required DateTime weekStart,
  }) {
    return "$userId|$sourceKey|${_trendDateToken(weekStart)}";
  }

  String _trendCaloriesCacheKey({
    required int userId,
    required DateTime weekStart,
  }) {
    return "$userId|${_trendDateToken(weekStart)}";
  }

  List<double>? _readTrendSleepWeekCache(String key) {
    final cached = _trendSleepWeekCache[key];
    return cached == null ? null : List<double>.from(cached);
  }

  List<double>? _readTrendCaloriesWeekCache(String key) {
    final cached = _trendCaloriesWeekCache[key];
    return cached == null ? null : List<double>.from(cached);
  }

  Map<String, dynamic>? _readDietSummaryCache(DateTime date) {
    final cached = _dietSummaryCache[_dayKey(date)];
    if (cached == null) return null;
    return Map<String, dynamic>.from(cached);
  }

  _ExerciseProgressSnapshot? _readExerciseProgressCache(DateTime date) {
    return _exerciseProgressCache[_dayKey(date)];
  }

  void _writeTrendSleepWeekCache(String key, List<double> values) {
    _trendSleepWeekCache[key] = List<double>.from(values);
    if (_trendSleepWeekCache.length > 84) {
      final keys = _trendSleepWeekCache.keys.toList()..sort();
      while (_trendSleepWeekCache.length > 84 && keys.isNotEmpty) {
        _trendSleepWeekCache.remove(keys.removeAt(0));
      }
    }
  }

  void _writeTrendCaloriesWeekCache(String key, List<double> values) {
    _trendCaloriesWeekCache[key] = List<double>.from(values);
    if (_trendCaloriesWeekCache.length > 84) {
      final keys = _trendCaloriesWeekCache.keys.toList()..sort();
      while (_trendCaloriesWeekCache.length > 84 && keys.isNotEmpty) {
        _trendCaloriesWeekCache.remove(keys.removeAt(0));
      }
    }
  }

  void _writeDietSummaryCache(DateTime date, Map<String, dynamic> summary) {
    _dietSummaryCache[_dayKey(date)] = Map<String, dynamic>.from(summary);
    if (_dietSummaryCache.length > 120) {
      final keys = _dietSummaryCache.keys.toList()..sort();
      while (_dietSummaryCache.length > 120 && keys.isNotEmpty) {
        _dietSummaryCache.remove(keys.removeAt(0));
      }
    }
  }

  void _writeExerciseProgressCache(
    DateTime date,
    _ExerciseProgressSnapshot snapshot,
  ) {
    _exerciseProgressCache[_dayKey(date)] = snapshot;
    if (_exerciseProgressCache.length > 120) {
      final keys = _exerciseProgressCache.keys.toList()..sort();
      while (_exerciseProgressCache.length > 120 && keys.isNotEmpty) {
        _exerciseProgressCache.remove(keys.removeAt(0));
      }
    }
  }

  DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _shouldUpdateTrendForDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _dayKey(date) == today;
  }

  bool _tryUpdateTrendSleepForDate(DateTime date, double hours) {
    final start = _trendWeekStart;
    if (start == null) return false;
    final weekStart = _trendWeekStartFor(date);
    if (weekStart != start) return false;
    final length = _trendSleep.isEmpty ? 7 : _trendSleep.length;
    final idx = _dayKey(date).difference(start).inDays;
    if (idx < 0 || idx >= length) return false;
    final next = _trendSleep.isEmpty
        ? List<double>.filled(7, 0.0)
        : List<double>.from(_trendSleep);
    if (next[idx] == hours) return true;
    next[idx] = hours;
    final cacheKey = _activeTrendSleepCacheKey;
    if (cacheKey != null) {
      _writeTrendSleepWeekCache(cacheKey, next);
    }
    if (mounted) {
      setState(() => _trendSleep = next);
    }
    return true;
  }

  bool _tryUpdateTrendCaloriesForDate(DateTime date, double calories) {
    final start = _trendWeekStart;
    if (start == null) return false;
    final weekStart = _trendWeekStartFor(date);
    if (weekStart != start) return false;
    final length = _trendCalories.isEmpty ? 7 : _trendCalories.length;
    final idx = _dayKey(date).difference(start).inDays;
    if (idx < 0 || idx >= length) return false;
    final next = _trendCalories.isEmpty
        ? List<double>.filled(7, 0.0)
        : List<double>.from(_trendCalories);
    if (next[idx] == calories) return true;
    next[idx] = calories;
    final cacheKey = _activeTrendCaloriesCacheKey;
    if (cacheKey != null) {
      _writeTrendCaloriesWeekCache(cacheKey, next);
    }
    if (mounted) {
      setState(() => _trendCalories = next);
    }
    return true;
  }

  bool _whoopLinked = false;
  bool _whoopLinkedKnown = false;
  bool? _whoopLinkedHint;
  bool _whoopLoading = false;
  int? _whoopRecovery;
  double? _whoopSleepHours;
  int? _whoopSleepScore;
  int? _whoopSleepDelta;
  int? _whoopRecoveryDelta;
  double? _whoopCycleStrain;
  double? _whoopBodyWeightKg;
  final Map<DateTime, WhoopWidgetSnapshot> _whoopSnapshotCache = {};
  DateTime? _whoopLoadingDate;
  int _whoopReqId = 0;

  bool? _fitbitLinkedHint;
  bool _fitbitLinked = false;
  bool? _stravaLinkedHint;
  bool _stravaLinked = false;
  bool _stravaActivitiesLoading = false;
  int? _stravaActivitiesCount;
  int _stravaActivitiesReqId = 0;
  bool _fitbitSummaryLoading = false;
  bool _fitbitActivityLoading = false;
  FitbitActivitySummary? _fitbitActivity;
  FitbitActivitySummary? _fitbitActivityLast;
  bool _fitbitHeartLoading = false;
  FitbitHeartSummary? _fitbitHeart;
  FitbitHeartSummary? _fitbitHeartLast;
  bool _fitbitSleepLoading = false;
  FitbitSleepSummary? _fitbitSleep;
  FitbitSleepSummary? _fitbitSleepLast;
  bool _fitbitVitalsLoading = false;
  FitbitVitalsSummary? _fitbitVitals;
  FitbitVitalsSummary? _fitbitVitalsLast;
  bool _fitbitBodyLoading = false;
  FitbitBodySummary? _fitbitBody;
  FitbitBodySummary? _fitbitBodyLast;
  final Map<DateTime, FitbitSummaryBundle?> _fitbitSummaryCache = {};
  DateTime? _fitbitSummaryLoadingDate;
  bool _healthRecoveryLoadLoading = false;
  HealthRecoveryLoadSummary? _healthRecoveryLoad;
  HealthRecoveryLoadSummary? _healthRecoveryLoadLast;
  final Map<DateTime, HealthRecoveryLoadSummary?> _healthRecoveryLoadCache = {};
  DateTime? _healthRecoveryLoadLoadingDate;
  DateTime _selectedDate = DateTime.now();
  int _weeklyDaysCount = 7;
  int? _exerciseTotal;
  int? _exerciseCompleted;
  String? _nextTrainingDayLabel;
  bool _nextTrainingDayAllDone = false;
  bool _exerciseLoading = false;
  bool _exerciseLoadedOnce = false;
  int _exerciseProgressReqId = 0;
  String? _exerciseProgramMode;
  int? _cachedTodayExerciseTotal;
  int? _cachedTodayExerciseCompleted;
  String? _cachedTodayNextTrainingDayLabel;
  bool _cachedTodayNextAllDone = false;
  String? _cachedTodayProgramMode;
  bool _cachedTodayLoadedOnce = false;
  int? _streakCount;
  bool _streakLoading = false;
  int? _cachedTodayDietConsumedCalories;
  int? _cachedTodayDietTargetCalories;
  String? _cachedTodayDietDayType;
  bool _cachedTodayDietLoaded = false;
  int _dietProgressReqId = 0;
  int? _cachedTodayTrainingDayId;
  bool _dietProgressLoading = false;
  int? _dietConsumedCalories;
  int? _dietTargetCalories;
  String? _dietDayType;

  TaqaDailyScore? _taqaScore;
  bool _taqaScoreLoading = false;
  int _taqaScoreReqId = 0;

  static const _stepsGoalKey = "dashboard_steps_goal";
  static const _sleepGoalKey = "dashboard_sleep_goal";
  static const _caloriesGoalKey = "dashboard_calories_goal";

  Color _colorForTag(String tag) {
    final normalized = tag.toLowerCase().trim();
    if (normalized.contains('update')) return const Color(0xFF6A5AE0);
    if (normalized.contains('nutrition')) return const Color(0xFF00BFA6);
    if (normalized.contains('workout') || normalized.contains('training')) {
      return const Color(0xFFFF8A00);
    }
    if (normalized.contains('reminder') || normalized.contains('journal')) {
      return const Color(0xFF35B6FF);
    }
    // Default accent in the same palette family.
    return const Color(0xFF6A5AE0);
  }

  void _changeDay(int deltaDays) {
    final currentWeekStart = _trendWeekStartFor(_selectedDate);
    final next = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + deltaDays,
    );
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return;
    final nextWeekStart = _trendWeekStartFor(next);
    final shouldReloadTrends =
        _trendWeekStart == null || nextWeekStart != currentWeekStart;
    final nextIsToday = next == todayOnly;
    final cachedWhoopTodaySleep = _whoopSnapshotCache[todayOnly]?.sleepHours;
    final shouldForceWhoopTodayRefresh =
        nextIsToday &&
        _hasWhoopSleepWidget &&
        (_whoopLinked || _whoopLinkedHint == true) &&
        ((cachedWhoopTodaySleep ?? 0) <= 0);
    final hasCachedToday =
        _cachedTodayLoadedOnce &&
        (_cachedTodayExerciseTotal != null ||
            _cachedTodayExerciseCompleted != null ||
            _cachedTodayNextTrainingDayLabel != null ||
            _cachedTodayNextAllDone);
    final cachedExercise = _readExerciseProgressCache(next);
    final hasCachedExercise =
        cachedExercise != null || (nextIsToday && hasCachedToday);
    final hasCachedDietToday =
        _cachedTodayDietLoaded &&
        (_cachedTodayDietConsumedCalories != null ||
            _cachedTodayDietTargetCalories != null ||
            _cachedTodayDietDayType != null);
    setState(() {
      _selectedDate = next;
      if (cachedExercise != null) {
        _exerciseLoadedOnce = true;
        _exerciseTotal = cachedExercise.total;
        _exerciseCompleted = cachedExercise.completed;
        _nextTrainingDayLabel = cachedExercise.nextLabel;
        _nextTrainingDayAllDone = cachedExercise.nextAllDone;
        _exerciseProgramMode = cachedExercise.programMode;
        _exerciseLoading = false;
      } else if (nextIsToday && hasCachedToday) {
        _exerciseLoadedOnce = _cachedTodayLoadedOnce;
        _exerciseTotal = _cachedTodayExerciseTotal;
        _exerciseCompleted = _cachedTodayExerciseCompleted;
        _nextTrainingDayLabel = _cachedTodayNextTrainingDayLabel;
        _nextTrainingDayAllDone = _cachedTodayNextAllDone;
        _exerciseProgramMode = _cachedTodayProgramMode;
        _exerciseLoading = false;
      } else {
        _exerciseLoadedOnce = false;
        _exerciseTotal = null;
        _exerciseCompleted = null;
        _nextTrainingDayLabel = null;
        _nextTrainingDayAllDone = false;
        _exerciseProgramMode = null;
      }
      if (nextIsToday && hasCachedDietToday) {
        _dietConsumedCalories = _cachedTodayDietConsumedCalories;
        _dietTargetCalories = _cachedTodayDietTargetCalories;
        _dietDayType = _cachedTodayDietDayType;
        _dietProgressLoading = false;
      } else {
        // Clear stale day values while fetching selected-date summary.
        _dietConsumedCalories = null;
        _dietTargetCalories = null;
        _dietDayType = null;
        _dietProgressLoading = true;
      }
      // Keep existing Fitbit values while new date loads to avoid zero/empty flicker.
    });
    _loadSteps();
    _loadSleep();
    _loadCalories();
    _loadWater();
    if (!(nextIsToday && hasCachedDietToday)) {
      _loadDietProgress();
    }
    _loadWeeklySteps();
    if (shouldReloadTrends) {
      _loadTrendSleep();
      _loadTrendCalories();
    }
    if (!hasCachedExercise) {
      _loadExerciseProgress();
    }
    _loadWhoopRecovery(force: shouldForceWhoopTodayRefresh);
    _loadFitbitSummary(force: true);
    _loadHealthRecoveryLoad(force: true);
    _loadTaqaScore();
  }

  void _openDateSheet() {
    final locale = AppLocalizations.of(context).locale.languageCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void change(int delta) {
              _changeDay(delta);
              setModalState(() {});
            }

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DateHeader(
                    selectedDate: _selectedDate,
                    onPrev: () => change(-1),
                    onNext: () => change(1),
                    canGoNext: !_isToday(),
                    label: DateFormat('dd/MM', locale).format(_selectedDate),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isToday() {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _ensureWiggle();
    AccountStorage.whoopChange.addListener(_onWhoopChanged);
    AccountStorage.stravaChange.addListener(_onStravaChanged);
    AccountStorage.accountChange.addListener(_onAccountChanged);
    AccountStorage.appleWatchChange.addListener(_onAppleWatchChanged);
    AccountStorage.trainingChange.addListener(_onTrainingChanged);
    AccountStorage.dietChange.addListener(_onDietChanged);
    AccountStorage.journalChange.addListener(_onJournalChanged);
    _loadStatOrder();
    _loadWhoopLinkedHint();
    _loadFitbitLinkedHint();
    _loadStravaLinkedHint();
    unawaited(_syncWearableDetectionBubble());
    _loadInitialData();
    unawaited(_syncBackfillThenRefreshTrends());
    _loadExerciseProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showUpdateAndReleaseNotes();
    });
  }

  Future<void> _showUpdateAndReleaseNotes() async {
    await ReleaseNotesNotice.showIfNeeded(context);
    await _maybeShowDailyJournalPrompt();
  }

  void _onWhoopChanged() {
    _whoopSnapshotCache.clear();
    _loadWhoopLinkedHint();
    _loadTrendSleep(force: true);
  }

  void _onStravaChanged() {
    if (!_isWidgetActive('strava_activities')) return;
    unawaited(_refreshStravaActivitiesWidgetAfterSignal());
  }

  Future<void> _refreshStravaActivitiesWidgetAfterSignal() async {
    await _loadStravaStatus();
    if (!mounted) return;
    await _loadStravaActivitiesCount(force: true);
  }

  void _onAccountChanged() {
    _loadStatOrder();
    _loadWhoopLinkedHint();
    _loadFitbitLinkedHint();
    _loadStravaLinkedHint();
    setState(() {
      _whoopLinked = false;
      _whoopLinkedKnown = false;
      _whoopLinkedHint = null;
      _whoopRecovery = null;
      _whoopSleepHours = null;
      _whoopSleepScore = null;
      _whoopSleepDelta = null;
      _whoopRecoveryDelta = null;
      _whoopCycleStrain = null;
      _whoopBodyWeightKg = null;
      _whoopLoading = false;
      _whoopLoadingDate = null;

      _fitbitLinked = false;
      _fitbitLinkedHint = null;
      _stravaLinked = false;
      _stravaLinkedHint = null;
      _stravaActivitiesLoading = false;
      _stravaActivitiesCount = null;
      _fitbitActivity = null;
      _fitbitHeart = null;
      _fitbitSleep = null;
      _fitbitVitals = null;
      _fitbitBody = null;
      _setFitbitLoadingFlags(false);

      _trendWeekStart = null;
      _trendCaloriesLoadedWeekStart = null;
      _trendSleep = const [];
      _trendCalories = const [];
      _trendSleepSourceKey = null;
      _activeTrendSleepCacheKey = null;
      _activeTrendCaloriesCacheKey = null;
      _whoopSnapshotCache.clear();
      _fitbitSummaryCache.clear();
      _fitbitSummaryLoadingDate = null;
      _healthRecoveryLoad = null;
      _healthRecoveryLoadLast = null;
      _healthRecoveryLoadLoading = false;
      _healthRecoveryLoadLoadingDate = null;
      _healthRecoveryLoadCache.clear();
      _dietSummaryCache.clear();
      _exerciseProgressCache.clear();
      _taqaScore = null;
      _taqaScoreLoading = false;
      _wearableBubbleVisible = false;
      _wearableBubbleType = null;
    });
    TaqaScoreApi.clearCache();
    _refreshAll();
    _loadExerciseProgress(force: true);
    unawaited(_syncWearableDetectionBubble());
    unawaited(_maybeShowDailyJournalPrompt());
  }

  void _onTrainingChanged() {
    _exerciseProgressCache.clear();
    _loadExerciseProgress(force: true);
    _loadCalories();
    _loadTrendCalories(force: true);
    _dietSummaryCache.remove(_dayKey(_selectedDate));
    _loadDietProgress(forceRefresh: true);
    _loadStreak();
  }

  void _onDietChanged() {
    _dietSummaryCache.clear();
    _cachedTodayDietConsumedCalories = null;
    _cachedTodayDietTargetCalories = null;
    _cachedTodayDietDayType = null;
    _cachedTodayDietLoaded = false;
    _loadDietProgress(forceRefresh: true);
    _loadStreak();
  }

  void _onJournalChanged() {
    _loadStreak();
  }

  Future<void> _onAppleWatchChanged() async {
    await _syncWearableDetectionBubble();
  }

  Future<void> _syncWearableDetectionBubble() async {
    final detected = await AccountStorage.getAppleWatchDetected();
    final wearableType = await AccountStorage.getWearableDetectedType();
    if (!mounted) return;
    setState(() {
      _wearableBubbleVisible = detected == true;
      _wearableBubbleType = detected == true ? wearableType : null;
    });
  }

  @override
  void dispose() {
    _wiggleController?.dispose();
    AccountStorage.whoopChange.removeListener(_onWhoopChanged);
    AccountStorage.stravaChange.removeListener(_onStravaChanged);
    AccountStorage.accountChange.removeListener(_onAccountChanged);
    AccountStorage.appleWatchChange.removeListener(_onAppleWatchChanged);
    AccountStorage.trainingChange.removeListener(_onTrainingChanged);
    AccountStorage.dietChange.removeListener(_onDietChanged);
    AccountStorage.journalChange.removeListener(_onJournalChanged);
    super.dispose();
  }

  void _ensureWiggle() {
    if (_wiggleController != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _wiggleController = controller;
    _wiggleAnim = Tween<double>(
      begin: -1,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.linear));
  }

  void _startWiggle() {
    if (!_isToday()) return;
    _ensureWiggle();
    if (_wiggling) return;
    setState(() => _wiggling = true);
    _wiggleController?.repeat(reverse: true);
  }

  void _stopWiggle() {
    if (!_wiggling) return;
    _endDrag(null);
    _wiggleController?.stop();
    _wiggleController?.reset();
    setState(() => _wiggling = false);
  }

  void _openWidgetLibrary() {
    if (!_isToday()) return;
    final available = _buildAvailableWidgetOptions();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Widgets",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim, secondary) {
        return WidgetLibrarySheet(
          options: available,
          onClose: () => Navigator.of(context).pop(),
          onSelect: (option) {
            Navigator.of(context).pop();
            _activateWidget(option.keyName);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _handleTrendCaloriesTap() async {
    if (!_isToday()) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CaloriesDetailPage()));
    await _loadGoals();
    await _loadCalories();
  }

  Future<void> _handleTrendSleepTap() async {
    if (!_isToday()) return;
    if (_statOrder.contains('whoop_sleep') && _whoopLinked) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SleepDetailPage(useWhoop: true),
        ),
      );
      return;
    }
    if (_statOrder.contains('fitbit_sleep') && _fitbitLinked) {
      final sleep = _fitbitSleepLoading
          ? (_fitbitSleepLast ?? _fitbitSleep)
          : _fitbitSleep;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => FitbitSleepSheet(summary: sleep, date: _selectedDate),
      );
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SleepDetailPage()));
    await _loadGoals();
    await _loadSleep();
  }

  DateTime _journalDay(DateTime date) {
    final shifted = date.subtract(
      const Duration(hours: DashboardPageState._journalResetHour),
    );
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  String _formatJournalDay(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _maybeShowDailyJournalPrompt() async {
    if (!mounted) return;
    if (NavigationService.journalNotificationPending ||
        NavigationService.launchedFromNotificationPayload ||
        NavigationService.isOnJournalPage) {
      return;
    }
    final now = DateTime.now();
    if (now.hour < _journalResetHour) return;

    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final shouldSkipForFirstSignupSession =
        await AccountStorage.consumeSkipDailyJournalPromptForNextSession(
          userId: userId,
        );
    if (shouldSkipForFirstSignupSession) {
      return;
    }

    final journalDay = _journalDay(now);
    final dayKey = _formatJournalDay(journalDay);
    final prefs = await SharedPreferences.getInstance();
    final promptShownKey = _journalPromptShownKeyForUser(userId);
    if (prefs.getString(promptShownKey) == dayKey) return;

    try {
      final entry = await DailyJournalApi.fetchForDate(userId, journalDay);
      if (entry != null) {
        await prefs.setString(promptShownKey, dayKey);
        return;
      }
    } catch (_) {
      // If we can't confirm, skip the prompt to avoid false positives.
      return;
    }

    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: "Daily journal check-in",
      message: "Take 60 seconds to log how you’re feeling today.",
      cancelText: "Later",
      confirmText: "Take me there",
      borderColor: const Color(0xFFD4AF37),
    );

    await prefs.setString(promptShownKey, dayKey);
    if (confirmed == true && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DailyJournalPage()));
    }
  }

  bool _isWidgetActive(String key) {
    switch (key) {
      case 'steps':
      case 'sleep':
      case 'water':
      case 'calories':
      case 'body':
        return _statOrder.contains(key);
      case 'whoop_sleep':
        return _statOrder.contains(key);
      case 'whoop_recovery':
      case 'whoop_cycle':
      case 'whoop_body':
        return _statOrder.contains(key);
      default:
        return _statOrder.contains(key);
    }
  }

  List<WidgetLibraryOption> _buildAvailableWidgetOptions() {
    final t = AppLocalizations.of(context).translate;
    final all = <WidgetLibraryOption>[
      WidgetLibraryOption(
        keyName: 'steps',
        title: t("dash_today_steps"),
        subtitle: "${t("dash_goal")} ${(_stepsGoal ?? 10000).toString()}",
        icon: Icons.directions_walk,
        accentColor: const Color(0xFF35B6FF),
      ),
      WidgetLibraryOption(
        keyName: 'sleep',
        title: t("dash_today_sleep"),
        subtitle:
            "${t("dash_goal")} ${(_sleepGoal ?? 8.0).toStringAsFixed(1)} ${t("dash_unit_hrs")}",
        icon: Icons.nights_stay,
        accentColor: const Color(0xFF9B8CFF),
      ),
      WidgetLibraryOption(
        keyName: 'water',
        title: t("dash_water_intake"),
        subtitle:
            "${t("dash_goal")} ${(_waterGoal ?? 2.5).toStringAsFixed(1)} ${t("dash_unit_l")}",
        icon: Icons.water_drop,
        accentColor: const Color(0xFF00BFA6),
      ),
      WidgetLibraryOption(
        keyName: 'calories',
        title: t("dash_calories_burned"),
        subtitle: "${t("dash_goal")} ${(_caloriesGoal ?? 500).toString()}",
        icon: Icons.local_fire_department,
        accentColor: const Color(0xFFFF8A00),
      ),
      WidgetLibraryOption(
        keyName: 'body',
        title: "Body measurements",
        subtitle: "Height & weight",
        icon: Icons.person,
        accentColor: const Color(0xFF6A5AE0),
      ),
      WidgetLibraryOption(
        keyName: 'health_recovery_load',
        title: "Recovery & load",
        subtitle: "RHR, HRV, zones, active minutes",
        icon: Icons.monitor_heart,
        accentColor: const Color(0xFF2EC4B6),
      ),
    ];
    if (_fitbitLinked || _fitbitLinkedHint == true) {
      all.add(
        WidgetLibraryOption(
          keyName: 'fitbit_activity',
          title: "Fitbit Daily Activity",
          subtitle: "Steps, distance, calories",
          icon: Icons.insights,
          accentColor: const Color(0xFF00B0B9),
        ),
      );
      all.add(
        WidgetLibraryOption(
          keyName: 'fitbit_heart',
          title: "Fitbit Heart & Cardio",
          subtitle: "Resting HR, HRV, VO₂ max",
          icon: Icons.favorite,
          accentColor: const Color(0xFF0C6A73),
        ),
      );
      all.add(
        WidgetLibraryOption(
          keyName: 'fitbit_sleep',
          title: "Fitbit Sleep",
          subtitle: "Duration, stages, goals",
          icon: Icons.nights_stay,
          accentColor: const Color(0xFF0C6A73),
        ),
      );
      all.add(
        WidgetLibraryOption(
          keyName: 'fitbit_vitals',
          title: "Fitbit Health Metrics",
          subtitle: "SpO₂, temp, breathing, ECG",
          icon: Icons.health_and_safety,
          accentColor: const Color(0xFF0C6A73),
        ),
      );
      all.add(
        WidgetLibraryOption(
          keyName: 'fitbit_body',
          title: "Fitbit Body",
          subtitle: "Weight",
          icon: Icons.monitor_weight,
          accentColor: const Color(0xFF0C6A73),
        ),
      );
    }
    if (_whoopLinked || _whoopLinkedHint == true) {
      all.addAll([
        WidgetLibraryOption(
          keyName: 'whoop_sleep',
          title: "Whoop Sleep",
          subtitle: "Sleep + efficiency",
          icon: Icons.nights_stay,
          accentColor: const Color(0xFF2D7CFF),
        ),
        WidgetLibraryOption(
          keyName: 'whoop_recovery',
          title: "Whoop Recovery",
          subtitle: "Recovery score",
          icon: Icons.monitor_heart,
          accentColor: const Color(0xFF4CD964),
        ),
        WidgetLibraryOption(
          keyName: 'whoop_cycle',
          title: "Whoop Cycle",
          subtitle: "Daily strain score",
          icon: Icons.loop,
          accentColor: const Color(0xFF2D7CFF),
        ),
        WidgetLibraryOption(
          keyName: 'whoop_body',
          title: "Whoop Body",
          subtitle: "Body measurements",
          icon: Icons.person,
          accentColor: const Color(0xFF2D7CFF),
        ),
      ]);
    }
    if (_stravaLinked || _stravaLinkedHint == true) {
      all.addAll([
        WidgetLibraryOption(
          keyName: 'strava_activities',
          title: "Strava Activities",
          subtitle: "Your activities with key metrics",
          icon: Icons.directions_run,
          accentColor: const Color(0xFFFC4C02),
        ),
      ]);
    }
    return all.where((item) => !_isWidgetActive(item.keyName)).toList();
  }

  void _swapStatOrder(String from, String to) {
    if (from == to) return;
    final fromIndex = _statOrder.indexOf(from);
    final toIndex = _statOrder.indexOf(to);
    if (fromIndex == -1 || toIndex == -1) return;
    setState(() {
      final tmp = _statOrder[fromIndex];
      _statOrder[fromIndex] = _statOrder[toIndex];
      _statOrder[toIndex] = tmp;
    });
    _saveStatOrder();
  }

  void _deactivateWidget(String key) {
    if (!_statOrder.contains(key)) return;
    setState(() {
      _statOrder.remove(key);
    });
    _saveStatOrder();
    if (_exclusiveGroupForKey(key) == 'sleep') {
      _loadTrendSleep();
    }
  }

  Future<void> _loadStatOrder() async {
    final sp = await SharedPreferences.getInstance();
    final userId = await AccountStorage.getUserId();
    _statOrderUserId = userId;
    final userKey = userId == null
        ? "dash_stat_order"
        : "dash_stat_order_u$userId";
    const legacyKey = "dash_stat_order";

    String? raw = sp.getString(userKey);
    if ((raw == null || raw.trim().isEmpty) && userId != null) {
      final legacy = sp.getString(legacyKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        raw = legacy;
        await sp.setString(userKey, legacy);
      }
    }

    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _statOrder
          ..clear()
          ..addAll(_defaultStatOrder);
      });
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final next = decoded.map((e) => e.toString()).toList();
        final filtered = <String>[];
        for (final item in next) {
          if (_allowedStatKeys.contains(item) && !filtered.contains(item)) {
            filtered.add(item);
          }
        }
        final pruned = <String>[];
        final seenGroup = <String>{};
        for (final item in filtered) {
          if (item == 'fitbit_steps') continue;
          final group = _exclusiveGroupForKey(item);
          if (group != null) {
            if (seenGroup.contains(group)) continue;
            seenGroup.add(group);
          }
          pruned.add(item);
        }
        if (pruned.isEmpty) {
          pruned.addAll(_defaultStatOrder);
        }
        final hasWhoop = pruned.any((item) => item.startsWith('whoop_'));
        final hasHealthRecoveryLoad = pruned.contains('health_recovery_load');
        if (!mounted) return;
        setState(() {
          _statOrder
            ..clear()
            ..addAll(pruned);
        });
        if (hasWhoop) {
          _loadWhoopRecovery();
        }
        if (hasHealthRecoveryLoad) {
          _loadHealthRecoveryLoad(force: true);
        }
        _loadTrendSleep(force: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statOrder
          ..clear()
          ..addAll(_defaultStatOrder);
      });
      _loadTrendSleep(force: true);
    }
  }

  Future<void> _loadWhoopLinkedHint() async {
    final hint = await AccountStorage.getWhoopLinked();
    if (!mounted) return;
    if (hint == null) {
      setState(() {
        _whoopLinkedHint = null;
        _whoopLinked = false;
        _whoopLinkedKnown = false;
      });
      return;
    }
    setState(() {
      _whoopLinkedHint = hint;
      _whoopLinked = hint;
      _whoopLinkedKnown = true;
      if (!hint) {
        _whoopRecovery = null;
        _whoopSleepHours = null;
        _whoopSleepScore = null;
        _whoopSleepDelta = null;
        _whoopRecoveryDelta = null;
        _whoopCycleStrain = null;
        _whoopBodyWeightKg = null;
        _whoopLoading = false;
      }
    });
    if (hint && _hasAnyWhoopWidget) {
      _loadWhoopRecovery();
    }
    _loadTrendSleep(force: true);
  }

  Future<void> _loadFitbitLinkedHint() async {
    final hint = await AccountStorage.getFitbitLinked();
    if (!mounted) return;
    if (hint == null) {
      setState(() {
        _fitbitLinkedHint = null;
        _fitbitLinked = false;
      });
      return;
    }
    setState(() {
      _fitbitLinkedHint = hint;
      _fitbitLinked = hint;
      if (!hint) {
        _fitbitSummaryCache.clear();
        _fitbitSummaryLoadingDate = null;
        _fitbitActivity = null;
        _fitbitHeart = null;
        _fitbitSleep = null;
        _fitbitVitals = null;
        _fitbitBody = null;
        _fitbitActivityLoading = false;
        _fitbitHeartLoading = false;
        _fitbitSleepLoading = false;
        _fitbitVitalsLoading = false;
        _fitbitBodyLoading = false;
      }
    });
    if (hint) {
      _loadFitbitSummary();
    }
    _loadTrendSleep(force: true);
  }

  Future<void> _loadStravaLinkedHint() async {
    final hint = await AccountStorage.getStravaLinked();
    if (!mounted) return;
    if (hint == null) {
      setState(() {
        _stravaLinkedHint = null;
        _stravaLinked = false;
      });
      return;
    }
    setState(() {
      _stravaLinkedHint = hint;
      _stravaLinked = hint;
    });
  }

  bool get _useWhoop {
    return false;
  }

  bool get _hasFitbitActivityWidget => _statOrder.contains('fitbit_activity');
  bool get _hasFitbitHeartWidget => _statOrder.contains('fitbit_heart');
  bool get _hasFitbitSleepWidget => _statOrder.contains('fitbit_sleep');
  bool get _hasFitbitVitalsWidget => _statOrder.contains('fitbit_vitals');
  bool get _hasFitbitBodyWidget => _statOrder.contains('fitbit_body');
  bool get _hasHealthRecoveryLoadWidget =>
      _statOrder.contains('health_recovery_load');
  bool get _hasWhoopSleepWidget => _statOrder.contains('whoop_sleep');
  bool get _hasAnyWhoopWidget =>
      _statOrder.contains('whoop_sleep') ||
      _statOrder.contains('whoop_recovery') ||
      _statOrder.contains('whoop_cycle') ||
      _statOrder.contains('whoop_body');

  Future<void> _saveStatOrder() async {
    final sp = await SharedPreferences.getInstance();
    final userId = await AccountStorage.getUserId();
    final effectiveUserId = userId ?? _statOrderUserId;
    final key = effectiveUserId == null
        ? "dash_stat_order"
        : "dash_stat_order_u$effectiveUserId";
    await sp.setString(key, jsonEncode(_statOrder));
  }

  void _pruneDeviceWidgets() {
    var changed = false;
    var sleepChanged = false;
    if (_fitbitLinkedHint == false) {
      if (_statOrder.remove('fitbit_activity')) changed = true;
      if (_statOrder.remove('fitbit_heart')) changed = true;
      if (_statOrder.remove('fitbit_sleep')) {
        changed = true;
        sleepChanged = true;
      }
      if (_statOrder.remove('fitbit_vitals')) changed = true;
      if (_statOrder.remove('fitbit_body')) changed = true;
    }
    if (_whoopLinkedHint == false) {
      const whoopKeys = [
        'whoop_sleep',
        'whoop_recovery',
        'whoop_cycle',
        'whoop_body',
      ];
      for (final key in whoopKeys) {
        if (_statOrder.remove(key)) {
          changed = true;
          if (key == 'whoop_sleep') {
            sleepChanged = true;
          }
        }
      }
    }
    if (_stravaLinkedHint == false) {
      const stravaKeys = ['strava_activities'];
      for (final key in stravaKeys) {
        if (_statOrder.remove(key)) {
          changed = true;
        }
      }
    }
    if (changed) {
      _saveStatOrder();
      if (mounted) setState(() {});
      if (sleepChanged) {
        _loadTrendSleep();
      }
    }
  }

  void _activateWidget(String key) {
    final group = _exclusiveGroupForKey(key);
    if (group != null) {
      final existing = _statOrder.firstWhere(
        (k) => _exclusiveGroupForKey(k) == group,
        orElse: () => "",
      );
      if (existing.isNotEmpty && existing != key) {
        AppToast.show(
          context,
          "Only one ${_exclusiveGroupLabel(group)} widget can be active",
          type: AppToastType.info,
        );
        return;
      }
    }

    if (key == 'fitbit_activity' ||
        key == 'fitbit_heart' ||
        key == 'fitbit_sleep' ||
        key == 'fitbit_vitals' ||
        key == 'fitbit_body') {
      if (!_fitbitLinked) {
        AppToast.show(context, "Connect Fitbit first", type: AppToastType.info);
        return;
      }
    } else if (key == 'whoop_sleep' ||
        key == 'whoop_recovery' ||
        key == 'whoop_cycle' ||
        key == 'whoop_body') {
      if (!_whoopLinked) {
        AppToast.show(context, "Connect Whoop first", type: AppToastType.info);
        return;
      }
    } else if (key == 'strava_activities') {
      if (!_stravaLinked) {
        AppToast.show(context, "Connect Strava first", type: AppToastType.info);
        return;
      }
    }

    if (!_statOrder.contains(key)) {
      setState(() => _statOrder.add(key));
      _saveStatOrder();
    }
    if (_exclusiveGroupForKey(key) == 'sleep') {
      _loadTrendSleep();
    }

    if (key.startsWith('whoop_')) {
      _loadWhoopRecovery(force: true);
    }
    if (key.startsWith('fitbit_')) {
      _loadFitbitSummary(force: true);
    }
    if (key.startsWith('strava_')) {
      _loadStravaStatus();
      _loadStravaActivitiesCount(force: true);
    }
    if (key == 'health_recovery_load') {
      _loadHealthRecoveryLoad(force: true);
    }
  }

  String? _exclusiveGroupForKey(String key) {
    switch (key) {
      case 'steps':
        return 'steps';
      case 'sleep':
      case 'fitbit_sleep':
      case 'whoop_sleep':
        return 'sleep';
      case 'body':
      case 'fitbit_body':
      case 'whoop_body':
        return 'body';
      default:
        return null;
    }
  }

  String _exclusiveGroupLabel(String group) {
    switch (group) {
      case 'steps':
        return 'steps';
      case 'sleep':
        return 'sleep';
      case 'body':
        return 'body';
      default:
        return 'metric';
    }
  }

  Widget _wiggleWrap(Widget child) {
    final anim = _wiggleAnim;
    if (anim == null || _wiggleController == null) return child;
    return AnimatedBuilder(
      animation: _wiggleController!,
      builder: (_, __) {
        final phase = _wiggling ? anim.value : 0.0;
        final wave = math.sin(phase * math.pi * 2);
        final angle = wave * 0.035; // ~2.0 degrees
        final dx = wave * 1.6;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
    );
  }

  void _beginDrag(String key, Offset globalPosition, Widget child) {
    if (_dragOverlay != null) return;
    final ctx = _tileKeys[key]?.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final topLeft = box.localToGlobal(Offset.zero);
    _dragKey = key;
    _dragTouchOffset = globalPosition - topLeft;
    _dragSize = size;
    _dragTopLeft = topLeft;
    _lastDragPos = globalPosition;
    _dragStartPos = globalPosition;
    _lastSwapTarget = null;
    _dragChild = child;
    setState(() {});

    _dragOverlay = OverlayEntry(
      builder: (_) {
        final offset = _dragTopLeft ?? topLeft;
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: size.width,
          height: size.height,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: _dragChild ?? child,
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_dragOverlay!);
  }

  void _updateDrag(Offset globalPosition) {
    if (_dragOverlay == null || _dragKey == null) return;
    final size = _dragSize;
    final touch = _dragTouchOffset ?? Offset.zero;
    if (size == null) return;
    _lastDragPos = globalPosition;
    _dragTopLeft = globalPosition - touch;
    _dragOverlay?.markNeedsBuild();

    final target = _findDropTarget(globalPosition, _dragKey!);
    if (target != null && target != _lastSwapTarget) {
      _swapStatOrder(_dragKey!, target);
      _lastSwapTarget = target;
    } else if (target == null) {
      _lastSwapTarget = null;
    }
  }

  void _endDrag(Offset? globalPosition) {
    if (_dragOverlay != null) {
      _dragOverlay?.remove();
      _dragOverlay = null;
    }
    final pos = globalPosition ?? _lastDragPos;
    if (pos != null && _dragKey != null) {
      final start = _dragStartPos;
      if (start != null && (pos - start).distance < 12) {
        _dragKey = null;
        _dragTouchOffset = null;
        _dragSize = null;
        _dragTopLeft = null;
        _lastDragPos = null;
        _dragStartPos = null;
        _dragChild = null;
        setState(() {});
        return;
      }
      final target = _findDropTarget(pos, _dragKey!);
      if (target != null) {
        _swapStatOrder(_dragKey!, target);
      }
    }
    _dragKey = null;
    _dragTouchOffset = null;
    _dragSize = null;
    _dragTopLeft = null;
    _lastDragPos = null;
    _dragStartPos = null;
    _lastSwapTarget = null;
    _dragChild = null;
    setState(() {});
  }

  String? _findDropTarget(Offset globalPosition, String fromKey) {
    String? best;
    double bestDist = double.infinity;
    for (final entry in _tileKeys.entries) {
      final key = entry.key;
      if (key == fromKey) continue;
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return key;
      final center = rect.center;
      final dist = (center - globalPosition).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = key;
      }
    }
    return bestDist <= 140 ? best : null;
  }

  Widget _buildTileChild(String key, Widget child) {
    final isDragging = _dragKey == key;
    return Opacity(opacity: isDragging ? 0.0 : 1.0, child: child);
  }

  Widget _buildRemovableTile(String key, Widget child) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(ignoring: _wiggling, child: child),
        Positioned(
          top: -6,
          left: -6,
          child: IgnorePointer(
            ignoring: !_wiggling,
            child: AnimatedOpacity(
              opacity: _wiggling ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 160),
              child: AnimatedScale(
                scale: _wiggling ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 160),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _deactivateWidget(key),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1F26),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: const Color(0xFFFF6B6B),
                        width: 1.6,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.remove,
                      color: Color(0xFFFF6B6B),
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(String key, Widget child) {
    final tile = _buildStatTileContent(key, child);
    return KeyedSubtree(
      key: _tileKeys.putIfAbsent(key, () => GlobalKey()),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (d) {
          if (!_isToday()) return;
          if (!_wiggling) _startWiggle();
          _beginDrag(key, d.globalPosition, tile);
        },
        onLongPressMoveUpdate: (d) => _updateDrag(d.globalPosition),
        onLongPressEnd: (d) => _endDrag(d.globalPosition),
        onPanStart: _wiggling
            ? (d) => _beginDrag(key, d.globalPosition, tile)
            : null,
        onPanUpdate: _wiggling ? (d) => _updateDrag(d.globalPosition) : null,
        onPanEnd: _wiggling ? (d) => _endDrag(_lastDragPos) : null,
        child: _buildTileChild(key, tile),
      ),
    );
  }

  Widget _buildStatTileContent(String key, Widget child) {
    final decorated = _buildRemovableTile(key, child);
    return _wiggleWrap(decorated);
  }

  Future<void> _loadTaqaScore() async {
    await TrainingResetCoordinator.ensureInitialized();
    final userId = await AccountStorage.getUserId();
    if (!mounted || userId == null || userId <= 0) return;
    final scoreDate = _taqaScoreDateForSelection();
    final reqId = ++_taqaScoreReqId;
    if (mounted) {
      setState(() => _taqaScoreLoading = true);
    }
    final result = await TaqaScoreApi.fetchDaily(
      userId: userId,
      date: scoreDate,
    );
    if (!mounted) return;
    if (reqId != _taqaScoreReqId) return;
    if (_taqaScoreDateForSelection() != scoreDate) return;
    setState(() {
      _taqaScore = result;
      _taqaScoreLoading = false;
    });
  }

  DateTime _taqaTodayByResetClock() {
    final now = TrainingResetCoordinator.currentNowUtc();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isTaqaTodaySelection() {
    return _dayKey(_selectedDate) == _taqaTodayByResetClock();
  }

  DateTime _taqaScoreDateForSelection() {
    if (_isTaqaTodaySelection()) {
      return _taqaTodayByResetClock().subtract(const Duration(days: 1));
    }
    return _dayKey(_selectedDate);
  }

  bool _isWhoopLoadingForSelectedDate() {
    if (!_whoopLoading || _whoopLoadingDate == null) return false;
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return _whoopLoadingDate == selected;
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUserInfo(),
      _loadNews(),
      _loadGoals(),
      _loadSteps(),
      _loadSleep(),
      _loadCalories(),
      _loadWater(),
      _loadDietProgress(),
      _loadWeeklySteps(),
      _loadTrendSleep(),
      _loadTrendCalories(),
      _loadStreak(),
      _loadWhoopRecovery(force: true),
      _loadHealthRecoveryLoad(force: true),
      _loadStravaStatus(),
      _loadTaqaScore(),
    ]);
    if (!mounted) return;
    _loadFitbitSummary(force: true);
  }

  Future<void> _syncBackfillThenRefreshTrends() async {
    if (_trendSyncRefreshInFlight) return;
    _trendSyncRefreshInFlight = true;
    try {
      await DailyProviderPushService().pushIfAfterOneAmLocal();
      if (!mounted) return;
      await Future.wait([
        _loadWeeklySteps(),
        _loadTrendSleep(),
        _loadTrendCalories(),
      ]);
    } catch (_) {
      // Keep dashboard usable even if sync/backfill fails.
    } finally {
      _trendSyncRefreshInFlight = false;
    }
  }

  Future<void> _refreshAll({
    bool refreshStrava = true,
    bool refreshTaqaScore = true,
  }) async {
    setState(() {
      _loading = true;
    });
    DailyMetricsApi.clearCache();
    TaqaScoreApi.clearCache();
    _healthRecoveryLoadCache.clear();
    _dietSummaryCache.clear();
    _exerciseProgressCache.clear();
    final futures = <Future<void>>[
      _loadUserInfo(),
      _loadNews(),
      _loadSteps(),
      _loadSleep(),
      _loadCalories(),
      _loadWater(),
      _loadWeeklySteps(),
      _loadTrendSleep(),
      _loadTrendCalories(),
      _loadWhoopRecovery(force: true),
      _loadHealthRecoveryLoad(force: true),
    ];
    if (refreshStrava) {
      futures.add(_loadStravaStatus());
    }
    if (refreshTaqaScore) {
      futures.add(_loadTaqaScore());
    }
    await Future.wait(futures);
    _loadFitbitSummary();
  }

  Future<void> _loadFitbitStatus({int attempt = 0}) async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitStatus(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() => _fitbitLinked = false);
      _pruneDeviceWidgets();
      return;
    }
    // Explicitly unlinked for this user: keep disabled and prune Fitbit widgets.
    if (_fitbitLinkedHint == false) {
      if (_fitbitLinked) {
        setState(() => _fitbitLinked = false);
      }
      _pruneDeviceWidgets();
      return;
    }
    try {
      final statusUrl = Uri.parse(
        "${ApiConfig.baseUrl}/fitbit/status?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final statusRes = await http
          .get(statusUrl, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (statusRes.statusCode != 200) {
        // Keep previous linked state on transient backend errors.
        return;
      }
      final statusData = jsonDecode(statusRes.body) as Map<String, dynamic>;
      final linked = statusData["linked"] == true;
      if (!mounted) return;
      setState(() => _fitbitLinked = linked);
      _fitbitLinkedHint = linked;
      AccountStorage.setFitbitLinked(linked);
      _pruneDeviceWidgets();
    } catch (_) {
      // Keep last known linked state on transient errors.
      return;
    }
  }

  Future<void> _loadStravaStatus({int attempt = 0}) async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadStravaStatus(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() {
        _stravaLinked = false;
        _stravaActivitiesLoading = false;
        _stravaActivitiesCount = null;
      });
      _pruneDeviceWidgets();
      return;
    }
    // Explicitly unlinked for this user: keep disabled and prune Strava widgets.
    if (_stravaLinkedHint == false) {
      if (_stravaLinked) {
        setState(() {
          _stravaLinked = false;
          _stravaActivitiesLoading = false;
          _stravaActivitiesCount = null;
        });
      } else if (_stravaActivitiesLoading || _stravaActivitiesCount != null) {
        setState(() {
          _stravaActivitiesLoading = false;
          _stravaActivitiesCount = null;
        });
      }
      _pruneDeviceWidgets();
      return;
    }
    try {
      final statusUrl = Uri.parse(
        "${ApiConfig.baseUrl}/strava/status?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final statusRes = await http
          .get(statusUrl, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (statusRes.statusCode != 200) {
        // Keep previous linked state on transient backend errors.
        return;
      }
      final statusData = jsonDecode(statusRes.body) as Map<String, dynamic>;
      final linked = statusData["linked"] == true;
      if (!mounted) return;
      setState(() {
        _stravaLinked = linked;
        if (!linked) {
          _stravaActivitiesLoading = false;
          _stravaActivitiesCount = null;
        }
      });
      _stravaLinkedHint = linked;
      AccountStorage.setStravaLinked(linked);
      _pruneDeviceWidgets();
      if (linked && _statOrder.contains('strava_activities')) {
        _loadStravaActivitiesCount(force: true);
      }
    } catch (_) {
      // Keep last known linked state on transient errors.
      return;
    }
  }

  Future<void> _loadStravaActivitiesCount({bool force = false}) async {
    if (!_stravaLinked) return;
    if (!_statOrder.contains('strava_activities')) return;
    if (_stravaActivitiesLoading && !force) return;
    final reqId = ++_stravaActivitiesReqId;
    if (mounted) {
      setState(() {
        _stravaActivitiesLoading = true;
      });
    }
    try {
      final data = await StravaService().fetchActivitiesOverview(
        perPage: 50,
        forceRefresh: force,
      );
      final raw = data['activities'];
      final count = raw is List ? raw.length : 0;
      if (!mounted || reqId != _stravaActivitiesReqId) return;
      setState(() {
        _stravaActivitiesCount = count;
        _stravaActivitiesLoading = false;
      });
    } catch (_) {
      if (!mounted || reqId != _stravaActivitiesReqId) return;
      setState(() {
        _stravaActivitiesLoading = false;
      });
    }
  }

  bool _flagTrue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == "true" || lower == "yes" || lower == "y") return true;
      final numeric = num.tryParse(value);
      return numeric != null && numeric != 0;
    }
    return false;
  }

  bool _complianceCompleted(dynamic compliance) {
    // Deprecated overload kept for back-compat; defaults to selected week.
    final anchor = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final weekStart = _weekStartMonday(anchor);
    final weekEnd = weekStart.add(const Duration(days: 6));
    return _complianceCompletedForWeek(compliance, weekStart, weekEnd);
  }

  DateTime _weekStartMonday(DateTime d) {
    return TrainingResetCoordinator.weekStartMonday(d);
  }

  String _dateToken(DateTime d) {
    return TrainingResetCoordinator.dateToken(d);
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  String _normalizeToken(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _historyDayIdentityKey(Map<String, dynamic> item) {
    final dayId = _parseInt(
      item['training_day_id'] ?? item['day_id'] ?? item['id'],
    );
    if (dayId != null && dayId > 0) return 'id:$dayId';

    final dayKey = _normalizeToken(item['day_key'] ?? item['dayKey']);
    if (dayKey.isNotEmpty) return 'key:$dayKey';

    final dayLabel = _normalizeToken(
      item['label'] ?? item['day_label'] ?? item['day_name'],
    );
    if (dayLabel.isNotEmpty) return 'label:$dayLabel';

    final dayIndex = _parseInt(
      item['day_index'] ?? item['day_number'] ?? item['day_no'] ?? item['day'],
    );
    if (dayIndex != null && dayIndex > 0) return 'index:$dayIndex';

    final dayDate = _parseDateTime(
      item['latest_date'] ??
          item['entry_date'] ??
          item['logged_at'] ??
          item['completed_at'] ??
          item['performed_at'],
    );
    if (dayDate != null) return 'date:${_dateToken(dayDate)}';

    return 'row:${item.hashCode}';
  }

  bool _historyRowInWeek(
    Map<String, dynamic> item,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final explicitWeekStart = _parseDateTime(item['week_start']);
    if (explicitWeekStart != null) {
      return _dateToken(_weekStartMonday(explicitWeekStart)) ==
          _dateToken(weekStart);
    }
    final rowDate = _parseDateTime(
      item['latest_date'] ??
          item['entry_date'] ??
          item['logged_at'] ??
          item['completed_at'] ??
          item['performed_at'],
    );
    if (rowDate == null) return false;
    return _isInWeek(rowDate, weekStart, weekEnd);
  }

  bool _historyRowWorked(Map<String, dynamic> item) {
    if (_flagTrue(item['is_completed_day'])) return true;
    if (_flagTrue(item['worked']) || _flagTrue(item['has_progress'])) {
      return true;
    }
    final completedCount = _parseInt(item['completed_count']) ?? 0;
    if (completedCount > 0) return true;
    final completedExercises = item['completed_exercises'];
    if (completedExercises is List && completedExercises.isNotEmpty) {
      return true;
    }
    final status = (item['status_text'] ?? item['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status.isEmpty) return false;
    return status.contains('progress') ||
        status.contains('complete') ||
        status.contains('done') ||
        status.contains('finish');
  }

  Future<int?> _historyWorkedDaysForWeek(
    int userId,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final resetNow = TrainingResetCoordinator.currentNowUtc();
    final deltaDays = resetNow.difference(weekStart).inDays.abs() + 14;
    final limitDays = math.min(540, math.max(42, deltaDays));
    final history = await TrainingService.fetchTrainingHistory(
      userId: userId,
      limitDays: limitDays,
    );
    final workedKeys = <String>{};
    for (final row in history) {
      if (!_historyRowInWeek(row, weekStart, weekEnd)) continue;
      if (!_historyRowWorked(row)) continue;
      workedKeys.add(_historyDayIdentityKey(row));
    }
    return workedKeys.length;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null)
        return DateTime(parsed.year, parsed.month, parsed.day);
    }
    if (value is num) {
      final intVal = value.toInt();
      try {
        // Accept seconds or milliseconds.
        if (intVal > 1000000000000) {
          final dt = DateTime.fromMillisecondsSinceEpoch(intVal);
          return DateTime(dt.year, dt.month, dt.day);
        }
        if (intVal > 1000000000) {
          final dt = DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
          return DateTime(dt.year, dt.month, dt.day);
        }
      } catch (_) {}
    }
    return null;
  }

  bool _isInWeek(DateTime date, DateTime weekStart, DateTime weekEnd) {
    return TrainingResetCoordinator.isInWeek(
      date,
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
  }

  bool _complianceCompletedForWeek(
    dynamic compliance,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (compliance == null) return false;
    if (compliance is Map) {
      final loggedAt = _parseDateTime(
        compliance['logged_at'] ??
            compliance['completed_at'] ??
            compliance['performed_at'] ??
            compliance['entry_date'],
      );
      if (loggedAt == null) return false;
      if (!_isInWeek(loggedAt, weekStart, weekEnd)) return false;
      final flags = [
        compliance['completed'],
        compliance['is_completed'],
        compliance['performed_sets'],
        compliance['performed_reps'],
        compliance['performed_time_seconds'],
        if (compliance['status'] != null)
          compliance['status'].toString().toLowerCase().contains("complete") ||
              compliance['status'].toString().toLowerCase().contains("done") ||
              compliance['status'].toString().toLowerCase().contains("finish"),
      ];
      return flags.any(_flagTrue);
    }
    if (compliance is Iterable) {
      return compliance.any(
        (item) => _complianceCompletedForWeek(item, weekStart, weekEnd),
      );
    }
    if (compliance is String) {
      try {
        final decoded = jsonDecode(compliance);
        return _complianceCompletedForWeek(decoded, weekStart, weekEnd);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  DateTime? _exerciseCompletionDate(Map<String, dynamic> ex) {
    final candidates = [
      ex['logged_at'],
      ex['completed_at'],
      ex['performed_at'],
      ex['entry_date'],
      ex['last_performed_at'],
    ];
    for (final c in candidates) {
      final dt = _parseDateTime(c);
      if (dt != null) return dt;
    }
    return null;
  }

  DateTime? _dayCompletionDate(Map<String, dynamic> day) {
    final candidates = [
      day['logged_at'],
      day['completed_at'],
      day['performed_at'],
      day['entry_date'],
      day['last_performed_at'],
    ];
    for (final c in candidates) {
      final dt = _parseDateTime(c);
      if (dt != null) return dt;
    }
    return null;
  }

  bool _isDayFlaggedCompletedForWeek(
    Map<String, dynamic> day,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final flags = [
      day['is_completed'],
      day['completed'],
      day['program_compliance_completed'],
    ];
    if (!flags.any(_flagTrue)) return false;
    final completionDate = _dayCompletionDate(day);
    if (completionDate == null) return false;
    return _isInWeek(completionDate, weekStart, weekEnd);
  }

  bool _isExerciseCompletedForWeek(
    Map<String, dynamic> ex,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (_complianceCompletedForWeek(
          ex['program_compliance'],
          weekStart,
          weekEnd,
        ) ||
        _complianceCompletedForWeek(ex['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final completionDate = _exerciseCompletionDate(ex);
    if (completionDate != null &&
        !_isInWeek(completionDate, weekStart, weekEnd)) {
      return false;
    }

    final flags = [
      ex['is_completed'],
      ex['completed'],
      ex['program_compliance_completed'],
      ex['performed_sets'],
      ex['performed_reps'],
      ex['performed_time_seconds'],
      ex['weight_used'],
    ];

    if (completionDate == null) return false;

    return flags.any(_flagTrue);
  }

  bool _isDayCompletedForWeek(
    Map<String, dynamic> day,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (_isDayFlaggedCompletedForWeek(day, weekStart, weekEnd)) {
      return true;
    }
    if (_complianceCompletedForWeek(
          day['program_compliance'],
          weekStart,
          weekEnd,
        ) ||
        _complianceCompletedForWeek(day['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) {
      return false;
    }
    for (final ex in exercises) {
      if (ex is Map<String, dynamic>) {
        if (_isExerciseCompletedForWeek(ex, weekStart, weekEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  String _dayLabelFor(Map<String, dynamic> day, int index) {
    final raw =
        day['day_label'] ??
        day['day_name'] ??
        day['label'] ??
        day['name'] ??
        day['title'];
    final label = raw?.toString().trim();
    if (label != null && label.isNotEmpty) return label;
    final dayId = day['day_id'] ?? day['id'];
    if (dayId != null) return "Day $dayId";
    return "Day ${index + 1}";
  }

  _NextTrainingDayResult _findNextUpTrainingDayLabel(
    Map<String, dynamic> program,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final days = program['days'];
    if (days is! List || days.isEmpty) {
      return const _NextTrainingDayResult();
    }
    var hasTrainingDay = false;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day is! Map<String, dynamic>) continue;
      final exercises = day['exercises'];
      if (exercises is! List || exercises.isEmpty) {
        // Skip rest days for "Next up".
        continue;
      }
      hasTrainingDay = true;
      if (!_isDayCompletedForWeek(day, weekStart, weekEnd)) {
        return _NextTrainingDayResult(label: _dayLabelFor(day, i));
      }
    }
    return _NextTrainingDayResult(allDone: hasTrainingDay);
  }

  int? _findTrainingDayIdForDate(Map<String, dynamic> program, DateTime date) {
    final days = program['days'];
    if (days is! List || days.isEmpty) return null;
    final target = DateTime(date.year, date.month, date.day);
    for (final day in days) {
      if (day is! Map<String, dynamic>) continue;
      final exercises = day['exercises'];
      if (exercises is! List || exercises.isEmpty) continue;
      for (final ex in exercises) {
        if (ex is! Map<String, dynamic>) continue;
        final compliance = ex['program_compliance'];
        DateTime? logged;
        if (compliance is Map<String, dynamic>) {
          logged = _parseDateTime(
            compliance['logged_at'] ??
                compliance['completed_at'] ??
                compliance['performed_at'] ??
                compliance['entry_date'],
          );
        }
        if (logged == null) {
          logged = _exerciseCompletionDate(ex);
        }
        if (logged != null &&
            logged.year == target.year &&
            logged.month == target.month &&
            logged.day == target.day) {
          final raw = day['day_index'] ?? day['day_id'] ?? day['id'];
          final parsed = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
          if (parsed != null && parsed > 0) return parsed;
        }
      }
    }
    return null;
  }

  _LocalTrainingProgress? _computeLocalTrainingProgress(
    Map<String, dynamic> program,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final days = program['days'];
    if (days is! List || days.isEmpty) return null;
    var total = 0;
    var completed = 0;
    for (final day in days) {
      if (day is! Map<String, dynamic>) continue;
      final exercises = day['exercises'];
      if (exercises is! List || exercises.isEmpty) {
        // Skip rest days for progress.
        continue;
      }
      total += 1;
      if (_isDayCompletedForWeek(day, weekStart, weekEnd)) {
        completed += 1;
      }
    }
    if (total <= 0) return null;
    return _LocalTrainingProgress(completed: completed, total: total);
  }

  DateTime? _parseDayDate(dynamic day) {
    if (day is Map) {
      for (final key in [
        'date',
        'day_date',
        'scheduled_date',
        'training_date',
        'day',
      ]) {
        final val = day[key];
        if (val is String && val.trim().isNotEmpty) {
          final parsed = DateTime.tryParse(val);
          if (parsed != null) {
            return DateTime(parsed.year, parsed.month, parsed.day);
          }
        }
        if (val is int) {
          try {
            final parsed = DateTime.fromMillisecondsSinceEpoch(val);
            return DateTime(parsed.year, parsed.month, parsed.day);
          } catch (_) {
            // ignore parse error and continue
          }
        }
      }
    }
    if (day is String && day.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(day);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return null;
  }

  bool _isOfflineError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  Future<void> _loadExerciseProgress({bool force = false}) async {
    final anchor = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final reqId = ++_exerciseProgressReqId;

    if (!force) {
      final cached = _readExerciseProgressCache(anchor);
      if (cached != null) {
        if (!mounted) return;
        if (reqId != _exerciseProgressReqId ||
            _dayKey(_selectedDate) != anchor) {
          return;
        }
        setState(() {
          _exerciseTotal = cached.total;
          _exerciseCompleted = cached.completed;
          _nextTrainingDayLabel = cached.nextLabel;
          _nextTrainingDayAllDone = cached.nextAllDone;
          _exerciseProgramMode = cached.programMode;
          _exerciseLoadedOnce = true;
          _exerciseLoading = false;
        });
        return;
      }
    }

    if (!force && _exerciseLoading) return;
    setState(() => _exerciseLoading = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        if (!mounted) return;
        if (reqId != _exerciseProgressReqId ||
            _dayKey(_selectedDate) != anchor) {
          return;
        }
        setState(() {
          _exerciseTotal = 0;
          _exerciseCompleted = 0;
          _exerciseLoadedOnce = true;
        });
        _writeExerciseProgressCache(
          anchor,
          const _ExerciseProgressSnapshot(
            total: 0,
            completed: 0,
            nextLabel: null,
            nextAllDone: false,
            programMode: null,
          ),
        );
        return;
      }

      await TrainingResetCoordinator.ensureInitialized();
      final weekStart = _weekStartMonday(anchor);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final today = TrainingResetCoordinator.currentNowUtc();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final isCurrentDay = anchor == todayOnly;

      try {
        final progress = await TrainingService.fetchTrainingProgress(
          userId: userId,
          start: weekStart,
          end: weekEnd,
        );
        final totalRaw = progress["total"];
        final total = totalRaw is int
            ? totalRaw
            : (totalRaw is num ? totalRaw.toInt() : 0);
        final doneRaw = progress["completed"];
        final doneFromProgress = doneRaw is int
            ? doneRaw
            : (doneRaw is num ? doneRaw.toInt() : 0);
        final mode = progress["program_mode"] as String?;
        int? doneFromHistory;
        try {
          doneFromHistory = await _historyWorkedDaysForWeek(
            userId,
            weekStart,
            weekEnd,
          );
        } catch (_) {
          // Keep backend progress value when history lookup fails.
        }
        final resolvedDone = doneFromHistory ?? doneFromProgress;
        final local = isCurrentDay
            ? await TrainingProgressStorage.getProgressForWeek(anchor)
            : null;
        final int? overrideCompleted =
            (local != null && local.completed > resolvedDone)
            ? local.completed
            : null;
        final int? overrideTotal = (local != null && local.total > 0)
            ? local.total
            : null;
        debugPrint(
          "Training progress db: user=$userId start=${weekStart.toIso8601String().split('T').first} "
          "end=${weekEnd.toIso8601String().split('T').first} completed=$resolvedDone total=$total"
          "${doneFromHistory != null ? " source=history" : ""}",
        );

        if (!mounted) return;
        if (reqId != _exerciseProgressReqId ||
            _dayKey(_selectedDate) != anchor) {
          return;
        }
        setState(() {
          _exerciseTotal = overrideTotal ?? total;
          _exerciseCompleted = overrideCompleted ?? resolvedDone;
          _exerciseLoadedOnce = true;
          _exerciseProgramMode = doneFromHistory != null ? "history" : mode;
        });
        if (isCurrentDay) {
          _cachedTodayExerciseTotal = overrideTotal ?? total;
          _cachedTodayExerciseCompleted = overrideCompleted ?? resolvedDone;
          _cachedTodayProgramMode = doneFromHistory != null ? "history" : mode;
          _cachedTodayLoadedOnce = true;
        }
        await _loadNextTrainingDayLabel(
          userId: userId,
          selectedDate: anchor,
          weekStart: weekStart,
          weekEnd: weekEnd,
          allowNetwork: true,
        );
        if (!mounted) return;
        if (reqId != _exerciseProgressReqId ||
            _dayKey(_selectedDate) != anchor) {
          return;
        }
        _writeExerciseProgressCache(
          anchor,
          _ExerciseProgressSnapshot(
            total: _exerciseTotal,
            completed: _exerciseCompleted,
            nextLabel: _nextTrainingDayLabel,
            nextAllDone: _nextTrainingDayAllDone,
            programMode: _exerciseProgramMode,
          ),
        );
        return;
      } catch (e) {
        if (!_isOfflineError(e)) rethrow;
      }

      // Offline fallback: use local progress storage.
      final cachedProgram = await TrainingService.fetchActiveProgramFromCache();
      final local = await TrainingProgressStorage.getProgressForWeek(anchor);
      int? totalFromProgram;
      if (cachedProgram is Map<String, dynamic>) {
        final raw = cachedProgram['training_days_per_week'];
        if (raw is int) {
          totalFromProgram = raw;
        } else if (raw is num) {
          totalFromProgram = raw.round();
        } else if (raw is String) {
          totalFromProgram = int.tryParse(raw);
        }
      }
      if (local != null) {
        if (!mounted) return;
        if (reqId != _exerciseProgressReqId ||
            _dayKey(_selectedDate) != anchor) {
          return;
        }
        setState(() {
          _exerciseTotal = (local.total > 0
              ? local.total
              : (totalFromProgram ?? 0));
          _exerciseCompleted = local.completed;
          _exerciseLoadedOnce = true;
          _exerciseProgramMode = "local";
        });
        if (isCurrentDay) {
          _cachedTodayExerciseTotal = (local.total > 0
              ? local.total
              : (totalFromProgram ?? 0));
          _cachedTodayExerciseCompleted = local.completed;
          _cachedTodayProgramMode = "local";
          _cachedTodayLoadedOnce = true;
        }
        await _loadNextTrainingDayLabel(
          userId: userId,
          selectedDate: anchor,
          weekStart: weekStart,
          weekEnd: weekEnd,
          allowNetwork: false,
        );
        if (!mounted) return;
        if (reqId != _exerciseProgressReqId ||
            _dayKey(_selectedDate) != anchor) {
          return;
        }
        _writeExerciseProgressCache(
          anchor,
          _ExerciseProgressSnapshot(
            total: _exerciseTotal,
            completed: _exerciseCompleted,
            nextLabel: _nextTrainingDayLabel,
            nextAllDone: _nextTrainingDayAllDone,
            programMode: _exerciseProgramMode,
          ),
        );
        return;
      }

      if (!mounted) return;
      if (reqId != _exerciseProgressReqId || _dayKey(_selectedDate) != anchor) {
        return;
      }
      setState(() {
        _exerciseTotal = null;
        _exerciseCompleted = null;
        _exerciseLoadedOnce = true;
        _exerciseProgramMode = "local";
      });
      if (isCurrentDay) {
        _cachedTodayExerciseTotal = null;
        _cachedTodayExerciseCompleted = null;
        _cachedTodayProgramMode = "local";
        _cachedTodayLoadedOnce = true;
      }
      await _loadNextTrainingDayLabel(
        userId: userId,
        selectedDate: anchor,
        weekStart: weekStart,
        weekEnd: weekEnd,
        allowNetwork: false,
      );
      if (!mounted) return;
      if (reqId != _exerciseProgressReqId || _dayKey(_selectedDate) != anchor) {
        return;
      }
      _writeExerciseProgressCache(
        anchor,
        _ExerciseProgressSnapshot(
          total: _exerciseTotal,
          completed: _exerciseCompleted,
          nextLabel: _nextTrainingDayLabel,
          nextAllDone: _nextTrainingDayAllDone,
          programMode: _exerciseProgramMode,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      if (reqId != _exerciseProgressReqId || _dayKey(_selectedDate) != anchor) {
        return;
      }
      setState(() {
        _exerciseTotal = null;
        _exerciseCompleted = null;
        _exerciseLoadedOnce = true;
      });
      _nextTrainingDayLabel = null;
      _nextTrainingDayAllDone = false;
      _writeExerciseProgressCache(
        anchor,
        const _ExerciseProgressSnapshot(
          total: null,
          completed: null,
          nextLabel: null,
          nextAllDone: false,
          programMode: null,
        ),
      );
    } finally {
      if (mounted &&
          reqId == _exerciseProgressReqId &&
          _dayKey(_selectedDate) == anchor) {
        setState(() => _exerciseLoading = false);
      }
    }
  }

  Future<void> refreshExerciseProgress() => _loadExerciseProgress();

  Future<void> _loadNextTrainingDayLabel({
    required int userId,
    required DateTime selectedDate,
    required DateTime weekStart,
    required DateTime weekEnd,
    required bool allowNetwork,
  }) async {
    final today = TrainingResetCoordinator.currentNowUtc();
    final selectedDayOnly = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isCurrentDay = selectedDayOnly == todayOnly;
    try {
      Map<String, dynamic>? program;
      if (allowNetwork) {
        try {
          program = await TrainingService.fetchActiveProgram(userId);
        } catch (e) {
          if (!_isOfflineError(e)) rethrow;
        }
      }
      if (program == null) {
        try {
          program = await TrainingService.fetchActiveProgramFromCache();
        } catch (_) {}
      }
      final result = program == null
          ? const _NextTrainingDayResult()
          : _findNextUpTrainingDayLabel(program, weekStart, weekEnd);
      final localProgress = program == null
          ? null
          : _computeLocalTrainingProgress(program, weekStart, weekEnd);
      final forceAllDone =
          localProgress != null &&
          localProgress.total > 0 &&
          localProgress.completed >= localProgress.total;
      final effectiveResult = forceAllDone
          ? const _NextTrainingDayResult(allDone: true)
          : result;
      final int? todaysTrainingDayId = (program != null && isCurrentDay)
          ? _findTrainingDayIdForDate(program, selectedDate)
          : null;
      if (!mounted) return;
      setState(() {
        _nextTrainingDayLabel = effectiveResult.label;
        _nextTrainingDayAllDone = effectiveResult.allDone;
      });
      if (isCurrentDay &&
          todaysTrainingDayId != null &&
          todaysTrainingDayId > 0 &&
          todaysTrainingDayId != _cachedTodayTrainingDayId) {
        _cachedTodayTrainingDayId = todaysTrainingDayId;
        try {
          await TrainingCalendarService.setDay(
            userId: userId,
            entryDate: selectedDate,
            dayType: 'training',
            trainingDayId: todaysTrainingDayId,
            source: 'dashboard.auto',
          );
          if (!_dietProgressLoading) {
            _dietSummaryCache.remove(_dayKey(selectedDate));
            await _loadDietProgress(forceRefresh: true);
          }
        } catch (_) {
          // Ignore mapping errors; diet may fall back to rest day.
        }
      }
      if (isCurrentDay) {
        _cachedTodayNextTrainingDayLabel = effectiveResult.label;
        _cachedTodayNextAllDone = effectiveResult.allDone;
        _cachedTodayLoadedOnce =
            _cachedTodayLoadedOnce || localProgress != null;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nextTrainingDayLabel = null;
        _nextTrainingDayAllDone = false;
      });
      if (isCurrentDay) {
        _cachedTodayNextTrainingDayLabel = null;
        _cachedTodayNextAllDone = false;
      }
    }
  }

  Future<void> _loadStreak() async {
    if (_streakLoading) return;
    setState(() => _streakLoading = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId == 0) {
        if (!mounted) return;
        setState(() => _streakCount = null);
        return;
      }
      final streak = await DailyMetricsApi.fetchStreak(userId);
      if (!mounted) return;
      setState(() => _streakCount = streak);
    } catch (e) {
      if (!mounted) return;
      if (_isOfflineError(e)) {
        setState(() => _streakCount = null);
      } else {
        setState(() => _streakCount = null);
      }
    } finally {
      if (mounted) setState(() => _streakLoading = false);
    }
  }

  Future<void> _loadSteps() async {
    setState(() {
      _stepsLoading = true;
    });
    try {
      int? steps;
      if (_isToday()) {
        steps = await StepsService().fetchTodaySteps();
      } else {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          final entry = await DailyMetricsApi.fetchForDate(
            userId,
            _selectedDate,
          );
          steps = entry?.steps;
          if (steps == null) {
            steps = await StepsService().fetchStepsForDay(_selectedDate);
          }
        }
      }
      if (!mounted) return;
      int? delta;
      if (steps != null) {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          try {
            final yesterday = _selectedDate.subtract(const Duration(days: 1));
            final entry = await DailyMetricsApi.fetchForDate(userId, yesterday);
            final ySteps = entry?.steps;
            if (ySteps != null) {
              delta = steps - ySteps;
            }
          } catch (_) {}
        }
      }
      setState(() {
        _todaySteps = steps;
        _stepsDelta = delta;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _todaySteps = null);
    } finally {
      if (mounted) {
        setState(() => _stepsLoading = false);
      }
    }
  }

  Future<void> _loadSleep() async {
    setState(() {
      _sleepLoading = true;
    });
    try {
      double? hours;
      if (_isToday()) {
        hours = await SleepService().fetchSleepHoursLast24h();
      } else {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          final entry = await DailyMetricsApi.fetchForDate(
            userId,
            _selectedDate,
          );
          hours = entry?.sleepHours;
          if (hours == null) {
            hours = await SleepService().fetchSleepForDay(_selectedDate);
          }
        }
      }
      if (!mounted) return;
      int? delta;
      if (hours != null) {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          try {
            final yesterday = _selectedDate.subtract(const Duration(days: 1));
            final entry = await DailyMetricsApi.fetchForDate(userId, yesterday);
            final ySleep = entry?.sleepHours;
            if (ySleep != null) {
              delta = _percentDelta(hours, ySleep);
            }
          } catch (_) {}
        }
      }
      setState(() {
        _sleepHours = hours;
        _sleepDelta = delta;
      });
      if (hours != null && _shouldUpdateTrendForDate(_selectedDate)) {
        _tryUpdateTrendSleepForDate(_selectedDate, hours);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _sleepHours = null);
    } finally {
      if (mounted) {
        setState(() => _sleepLoading = false);
      }
    }
  }

  Future<void> _loadCalories() async {
    setState(() {
      _caloriesLoading = true;
    });
    try {
      final caloriesService = CaloriesService();
      final trainingCaloriesService = TrainingCaloriesService();
      var displayKcal = 0;
      var cardioKcalForSurplus = 0;
      final normalizedSelectedDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      if (_isToday()) {
        final cardio = await caloriesService.fetchTodayCalories();
        final training = await trainingCaloriesService
            .fetchEstimatedCaloriesForDay(normalizedSelectedDay);
        displayKcal = cardio + training;
        cardioKcalForSurplus = cardio;
      } else {
        final cardio = await caloriesService.fetchCaloriesForDay(_selectedDate);
        final training = await trainingCaloriesService
            .fetchEstimatedCaloriesForDay(normalizedSelectedDay);
        final localTotal = cardio + training;
        cardioKcalForSurplus = cardio;
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          final entry = await DailyMetricsApi.fetchForDate(
            userId,
            _selectedDate,
          );
          final dbCalories = entry?.calories;
          displayKcal = localTotal > 0 ? localTotal : (dbCalories ?? 0);
        } else {
          displayKcal = localTotal;
        }
      }
      final manualDisplayTotals = await caloriesService
          .getManualTotalDisplayEntries();
      final manualDisplayForSelected =
          manualDisplayTotals[normalizedSelectedDay];
      if (manualDisplayForSelected != null) {
        displayKcal = manualDisplayForSelected;
      }
      if (!mounted) return;
      int? delta;
      final userId = await AccountStorage.getUserId();
      if (userId != null) {
        try {
          final yesterday = _selectedDate.subtract(const Duration(days: 1));
          final entry = await DailyMetricsApi.fetchForDate(userId, yesterday);
          final yCal = entry?.calories;
          if (yCal != null) {
            delta = displayKcal - yCal;
          }
        } catch (_) {}
      }
      setState(() {
        _todayCalories = displayKcal;
        _caloriesDelta = delta;
      });
      if (_shouldUpdateTrendForDate(_selectedDate)) {
        _tryUpdateTrendCaloriesForDate(_selectedDate, displayKcal.toDouble());
      }
      // Submit cardio burn only for surplus.
      // Avoid sending 0 for past days when local health data is unavailable.
      if (userId != null && (_isToday() || cardioKcalForSurplus > 0)) {
        try {
          await DailyMetricsApi.submitBurn(
            userId: userId,
            caloriesBurned: cardioKcalForSurplus,
            entryDate: _selectedDate,
          );
          if (_isToday()) {
            await DietService.fetchCurrentTargets(userId);
            DietService.notifyTargetsUpdatedAfterBurn();
          }
        } catch (_) {
          // Ignore; surplus will run on next submit or full metrics upsert.
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _todayCalories = null);
    } finally {
      if (mounted) {
        setState(() => _caloriesLoading = false);
      }
    }
  }

  Future<void> _loadWater() async {
    setState(() {
      _waterLoading = true;
    });
    try {
      final service = WaterService();
      final goal = await service.getGoal();
      double? intake;
      if (_isToday()) {
        intake = await service.getIntakeForDay(_selectedDate);
      } else {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          final entry = await DailyMetricsApi.fetchForDate(
            userId,
            _selectedDate,
          );
          intake = entry?.waterLiters;
          if (intake == null) {
            intake = await service.getIntakeForDay(_selectedDate);
          }
        }
      }
      if (!mounted) return;
      int? delta;
      if (intake != null) {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          try {
            final yesterday = _selectedDate.subtract(const Duration(days: 1));
            final entry = await DailyMetricsApi.fetchForDate(userId, yesterday);
            final yWater = entry?.waterLiters;
            if (yWater != null) {
              delta = _percentDelta(intake, yWater);
            }
          } catch (_) {}
        }
      }
      setState(() {
        _waterGoal = goal;
        _waterIntake = intake;
        _waterDelta = delta;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _waterGoal = null;
        _waterIntake = null;
      });
    } finally {
      if (mounted) {
        setState(() => _waterLoading = false);
      }
    }
  }

  Future<void> _loadDietProgress({bool forceRefresh = false}) async {
    final requestedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final reqId = ++_dietProgressReqId;

    if (!forceRefresh) {
      final memoryCached = _readDietSummaryCache(requestedDate);
      if (memoryCached != null) {
        if (!mounted) return;
        if (reqId != _dietProgressReqId) return;
        if (_dayKey(_selectedDate) != _dayKey(requestedDate)) return;
        _applyDietSummary(memoryCached, forDate: requestedDate);
        return;
      }

      final persistedCached = await DietDaySummaryStorage.loadSummaryForDate(
        requestedDate,
      );
      if (!mounted) return;
      if (reqId != _dietProgressReqId) return;
      if (_dayKey(_selectedDate) != _dayKey(requestedDate)) return;
      if (persistedCached != null) {
        _writeDietSummaryCache(requestedDate, persistedCached);
        _applyDietSummary(persistedCached, forDate: requestedDate);
        return;
      }
    }

    setState(() => _dietProgressLoading = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        if (!mounted) return;
        if (reqId != _dietProgressReqId) return;
        if (_dayKey(_selectedDate) != _dayKey(requestedDate)) return;
        setState(() {
          _dietConsumedCalories = null;
          _dietTargetCalories = null;
          _dietDayType = null;
          _dietProgressLoading = false;
        });
        return;
      }

      final summary = await DietService.fetchDaySummary(
        userId,
        date: requestedDate,
      );
      _writeDietSummaryCache(requestedDate, summary);
      try {
        await DietDaySummaryStorage.saveSummaryForDate(requestedDate, summary);
      } catch (_) {
        // Ignore cache errors
      }

      if (!mounted) return;
      if (reqId != _dietProgressReqId) return;
      if (_dayKey(_selectedDate) != _dayKey(requestedDate)) return;
      _applyDietSummary(summary, forDate: requestedDate);
    } catch (e) {
      if (_isOfflineError(e)) {
        final cached = await DietDaySummaryStorage.loadSummaryForDate(
          requestedDate,
        );
        if (!mounted) return;
        if (reqId != _dietProgressReqId) return;
        if (_dayKey(_selectedDate) != _dayKey(requestedDate)) return;
        if (cached != null) {
          _writeDietSummaryCache(requestedDate, cached);
          _applyDietSummary(cached, forDate: requestedDate);
          return;
        }
      }
      if (!mounted) return;
      if (reqId != _dietProgressReqId) return;
      if (_dayKey(_selectedDate) != _dayKey(requestedDate)) return;
      setState(() {
        _dietConsumedCalories = null;
        _dietTargetCalories = null;
        _dietDayType = null;
        _dietProgressLoading = false;
      });
    }
  }

  void _applyDietSummary(
    Map<String, dynamic> summary, {
    required DateTime forDate,
  }) {
    final liveRaw = summary["live"];
    Map<String, dynamic>? live = liveRaw is Map
        ? liveRaw.cast<String, dynamic>()
        : null;
    if (live == null) {
      if (summary["target"] is Map ||
          summary["consumed"] is Map ||
          summary["remaining"] is Map) {
        live = summary;
      }
    }
    final target = (live?["target"] is Map)
        ? (live?["target"] as Map).cast<String, dynamic>()
        : null;
    final consumed = (live?["consumed"] is Map)
        ? (live?["consumed"] as Map).cast<String, dynamic>()
        : null;
    int? targetCal;
    int? consumedCal;

    int? _asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v);
      return null;
    }

    targetCal = _asInt(target?["calories"]);
    consumedCal = _asInt(consumed?["calories"]);

    setState(() {
      _dietConsumedCalories = consumedCal;
      _dietTargetCalories = targetCal;
      _dietDayType = live?["day_type"]?.toString();
      _dietProgressLoading = false;
    });
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selectedOnly = DateTime(forDate.year, forDate.month, forDate.day);
    if (selectedOnly == todayOnly) {
      _cachedTodayDietConsumedCalories = consumedCal;
      _cachedTodayDietTargetCalories = targetCal;
      _cachedTodayDietDayType = live?["day_type"]?.toString();
      _cachedTodayDietLoaded = true;
    }
  }

  double? _parseWhoopSleepHours(Map<String, dynamic> data) {
    final sleep = data["sleep"];
    if (sleep is! Map<String, dynamic>) return null;

    dynamic pick(dynamic v) => v is Map<String, dynamic> ? null : v;

    dynamic score = sleep["score"];
    final stage = score is Map<String, dynamic> ? score["stage_summary"] : null;
    if (stage is Map<String, dynamic>) {
      final light = stage["total_light_sleep_time_milli"];
      final slow = stage["total_slow_wave_sleep_time_milli"];
      final rem = stage["total_rem_sleep_time_milli"];
      if (light is num && slow is num && rem is num) {
        final totalMs = light + slow + rem;
        if (totalMs > 0) return totalMs / 3600000.0;
      }
      if (light is String && slow is String && rem is String) {
        final l = double.tryParse(light);
        final s = double.tryParse(slow);
        final r = double.tryParse(rem);
        if (l != null && s != null && r != null) {
          final totalMs = l + s + r;
          if (totalMs > 0) return totalMs / 3600000.0;
        }
      }
    }
    return null;
  }

  int? _percentDelta(num current, num previous) {
    if (previous == 0) return null;
    return (((current - previous) / previous) * 100).round();
  }

  int? _parseWhoopSleepScore(Map<String, dynamic> data) {
    final sleep = data["sleep"];
    if (sleep is! Map<String, dynamic>) return null;

    dynamic pick(dynamic v) => v is Map<String, dynamic> ? null : v;

    final scoreNode = sleep["score"];
    final candidates = [
      scoreNode is Map<String, dynamic> ? scoreNode["sleep_score"] : null,
      scoreNode is Map<String, dynamic> ? scoreNode["score"] : null,
      scoreNode is Map<String, dynamic> ? scoreNode["value"] : null,
      scoreNode is Map<String, dynamic>
          ? scoreNode["sleep_score_percent"]
          : null,
      sleep["sleep_score"],
      sleep["score"],
      sleep["value"],
    ];

    for (final c in candidates) {
      final v = pick(c);
      if (v is num) return v.round();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed.round();
      }
    }
    return null;
  }

  double? _durationFromStartEnd(Map<String, dynamic> sleep) {
    final startCandidates = [
      sleep["start"],
      sleep["start_time"],
      sleep["start_datetime"],
      sleep["start_at"],
    ];
    final endCandidates = [
      sleep["end"],
      sleep["end_time"],
      sleep["end_datetime"],
      sleep["end_at"],
    ];

    DateTime? parse(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      if (v is int) {
        final ms = v > 1000000000000 ? v : v * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
      if (v is double) {
        final ms = v > 1000000000000 ? v : v * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);
      }
      return null;
    }

    DateTime? start;
    for (final s in startCandidates) {
      start = parse(s);
      if (start != null) break;
    }
    DateTime? end;
    for (final e in endCandidates) {
      end = parse(e);
      if (end != null) break;
    }
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    if (diff.isNegative) return null;
    return diff.inMinutes / 60.0;
  }

  Future<void> _loadWhoopRecovery({bool force = false}) async {
    final int requestId = ++_whoopReqId;
    final targetDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (!force &&
        _whoopLoading &&
        _whoopLoadingDate != null &&
        _whoopLoadingDate == targetDate) {
      return;
    }
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final bool isCurrentDay = targetDate == todayOnly;
    if (userId == null || userId == 0) {
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopLinked = false;
        _whoopLinkedKnown = true;
        _whoopRecovery = null;
        _whoopSleepHours = null;
        _whoopSleepScore = null;
        _whoopSleepDelta = null;
        _whoopRecoveryDelta = null;
        _whoopCycleStrain = null;
        _whoopLoading = false;
        _whoopBodyWeightKg = null;
      });
      return;
    }
    if (!_hasAnyWhoopWidget) {
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopLinked = _whoopLinkedHint == true;
        _whoopLinkedKnown = _whoopLinkedHint != null;
        _whoopRecovery = null;
        _whoopSleepHours = null;
        _whoopSleepScore = null;
        _whoopSleepDelta = null;
        _whoopRecoveryDelta = null;
        _whoopCycleStrain = null;
        _whoopLoading = false;
        _whoopBodyWeightKg = null;
      });
      return;
    }
    if (_whoopLinkedHint == false) {
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopLinked = false;
        _whoopLinkedKnown = true;
        _whoopRecovery = null;
        _whoopSleepHours = null;
        _whoopSleepScore = null;
        _whoopSleepDelta = null;
        _whoopRecoveryDelta = null;
        _whoopCycleStrain = null;
        _whoopLoading = false;
        _whoopBodyWeightKg = null;
      });
      _pruneDeviceWidgets();
      return;
    }

    final cachedServiceSnapshot = WhoopWidgetDataService.cachedSnapshotForDate(
      userId: userId,
      date: targetDate,
    );
    if (cachedServiceSnapshot != null) {
      _whoopSnapshotCache[targetDate] = cachedServiceSnapshot;
    }
    final cached = _whoopSnapshotCache[targetDate];
    if (!force && cached != null) {
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopLinked = cached.linked;
        _whoopLinkedKnown = cached.linkedKnown;
        _whoopLinkedHint = cached.linked;
        _whoopRecovery = cached.recoveryScore;
        _whoopSleepHours = cached.sleepHours;
        _whoopSleepScore = cached.sleepScore;
        _whoopSleepDelta = cached.sleepDelta;
        _whoopRecoveryDelta = cached.recoveryDelta;
        _whoopLoading = false;
        _whoopLoadingDate = null;
        _whoopCycleStrain = cached.cycleStrain;
        _whoopBodyWeightKg = cached.bodyWeightKg;
      });
      final shouldUpdateTrend =
          cached.sleepHours != null &&
          cached.sleepHours! > 0 &&
          _shouldUpdateTrendForDate(_selectedDate);
      final didUpdateTrend =
          shouldUpdateTrend &&
          _tryUpdateTrendSleepForDate(_selectedDate, cached.sleepHours!);
      final expectedSource = _trendSleepSourceForCurrentWidgets();
      if (_trendSleepSourceKey != expectedSource) {
        _loadTrendSleep(force: true);
      } else if (!didUpdateTrend && shouldUpdateTrend) {
        _loadTrendSleep(force: true);
      }
      return;
    }

    setState(() {
      _whoopLoading = true;
      _whoopLoadingDate = targetDate;
    });
    try {
      final snapshot = await WhoopWidgetDataService().fetchForDate(targetDate);
      if (requestId != _whoopReqId) return;

      if (!mounted) return;
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopLinked = snapshot.linked;
        _whoopLinkedKnown = snapshot.linkedKnown;
        _whoopLinkedHint = snapshot.linked;
        _whoopRecovery = snapshot.recoveryScore;
        _whoopSleepHours = snapshot.sleepHours;
        _whoopSleepScore = snapshot.sleepScore;
        _whoopSleepDelta = snapshot.sleepDelta;
        _whoopRecoveryDelta = snapshot.recoveryDelta;
        _whoopLoading = false;
        _whoopLoadingDate = null;
        _whoopCycleStrain = snapshot.cycleStrain;
        _whoopBodyWeightKg = snapshot.bodyWeightKg;
      });
      _whoopSnapshotCache[targetDate] = snapshot;
      if (_whoopSnapshotCache.length > 21) {
        final keys = _whoopSnapshotCache.keys.toList()..sort();
        while (_whoopSnapshotCache.length > 21 && keys.isNotEmpty) {
          _whoopSnapshotCache.remove(keys.removeAt(0));
        }
      }
      final shouldUpdateTrend =
          snapshot.sleepHours != null &&
          snapshot.sleepHours! > 0 &&
          _shouldUpdateTrendForDate(_selectedDate);
      final didUpdateTrend =
          shouldUpdateTrend &&
          _tryUpdateTrendSleepForDate(_selectedDate, snapshot.sleepHours!);
      AccountStorage.setWhoopLinked(snapshot.linked);
      _pruneDeviceWidgets();
      final expectedSource = _trendSleepSourceForCurrentWidgets();
      if (_trendSleepSourceKey != expectedSource) {
        _loadTrendSleep(force: true);
      } else if (!didUpdateTrend && shouldUpdateTrend) {
        _loadTrendSleep(force: true);
      }
    } catch (_) {
      if (!mounted) return;
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopRecovery = null;
        _whoopSleepHours = null;
        _whoopSleepScore = null;
        if (!isCurrentDay) {
          _whoopCycleStrain = null;
          _whoopBodyWeightKg = null;
        }
        _whoopLoading = false;
        _whoopLoadingDate = null;
      });
    }
  }

  void _applyHealthRecoveryLoad(HealthRecoveryLoadSummary? summary) {
    _healthRecoveryLoad = summary;
    _healthRecoveryLoadLast = summary ?? _healthRecoveryLoadLast;
    _healthRecoveryLoadLoading = false;
  }

  HealthRecoveryLoadSummary? _healthRecoveryLoadFromEntry(
    DailyMetricsEntry? entry,
  ) {
    if (entry == null) return null;
    final zones = HealthHeartZones(
      outOfRangeMinutes: entry.heartZoneOutOfRangeMinutes ?? 0,
      fatBurnMinutes: entry.heartZoneFatBurnMinutes ?? 0,
      cardioMinutes: entry.heartZoneCardioMinutes ?? 0,
      peakMinutes: entry.heartZonePeakMinutes ?? 0,
    );
    final summary = HealthRecoveryLoadSummary(
      restingHeartRate: entry.restingHr,
      hrvMs: entry.hrvMs,
      activeMinutes: entry.activeMinutes,
      zones: zones.totalMinutes > 0 ? zones : null,
    );
    return summary.hasAnyData ? summary : null;
  }

  bool _needsHealthRecoveryLoadFallback(HealthRecoveryLoadSummary? summary) {
    if (summary == null) return true;
    final hasResting = (summary.restingHeartRate ?? 0) > 0;
    final hasHrv = (summary.hrvMs ?? 0) > 0;
    final hasActiveMinutes = (summary.activeMinutes ?? 0) > 0;
    final hasZones = (summary.zones?.totalMinutes ?? 0) > 0;
    return !hasResting || !hasHrv || !hasActiveMinutes || !hasZones;
  }

  int? _preferPositiveInt(int? preferred, int? fallback) {
    if ((preferred ?? 0) > 0) return preferred;
    if ((fallback ?? 0) > 0) return fallback;
    return null;
  }

  double? _preferPositiveDouble(double? preferred, double? fallback) {
    if ((preferred ?? 0) > 0) return preferred;
    if ((fallback ?? 0) > 0) return fallback;
    return null;
  }

  HealthHeartZones? _mergeZones(
    HealthHeartZones? primary,
    HealthHeartZones? fallback,
  ) {
    final outOfRange =
        _preferPositiveInt(
          primary?.outOfRangeMinutes,
          fallback?.outOfRangeMinutes,
        ) ??
        0;
    final fatBurn =
        _preferPositiveInt(primary?.fatBurnMinutes, fallback?.fatBurnMinutes) ??
        0;
    final cardio =
        _preferPositiveInt(primary?.cardioMinutes, fallback?.cardioMinutes) ??
        0;
    final peak =
        _preferPositiveInt(primary?.peakMinutes, fallback?.peakMinutes) ?? 0;

    final merged = HealthHeartZones(
      outOfRangeMinutes: outOfRange,
      fatBurnMinutes: fatBurn,
      cardioMinutes: cardio,
      peakMinutes: peak,
    );
    return merged.totalMinutes > 0 ? merged : null;
  }

  HealthRecoveryLoadSummary? _mergeHealthRecoveryLoad(
    HealthRecoveryLoadSummary? primary,
    HealthRecoveryLoadSummary? fallback,
  ) {
    if (primary == null) return fallback;
    if (fallback == null) return primary;
    final merged = HealthRecoveryLoadSummary(
      restingHeartRate: _preferPositiveInt(
        primary.restingHeartRate,
        fallback.restingHeartRate,
      ),
      hrvMs: _preferPositiveDouble(primary.hrvMs, fallback.hrvMs),
      activeMinutes: _preferPositiveInt(
        primary.activeMinutes,
        fallback.activeMinutes,
      ),
      zones: _mergeZones(primary.zones, fallback.zones),
    );
    return merged.hasAnyData ? merged : null;
  }

  Future<void> _loadHealthRecoveryLoad({bool force = false}) async {
    if (!_hasHealthRecoveryLoadWidget) return;
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (!force &&
        _healthRecoveryLoadLoading &&
        _healthRecoveryLoadLoadingDate == selectedDay) {
      return;
    }
    if (!force && _healthRecoveryLoadCache.containsKey(selectedDay)) {
      final cached = _healthRecoveryLoadCache[selectedDay];
      if (!mounted) return;
      setState(() {
        _applyHealthRecoveryLoad(cached);
        _healthRecoveryLoadLoadingDate = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _healthRecoveryLoadLoading = true;
      _healthRecoveryLoadLoadingDate = selectedDay;
    });
    try {
      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);
      final isToday = selectedDay == todayOnly;
      HealthRecoveryLoadSummary? summary;
      HealthRecoveryLoadSummary? localSummary;

      final userId = await AccountStorage.getUserId();
      if (userId != null) {
        final entry = await DailyMetricsApi.fetchForDate(userId, selectedDay);
        summary = _healthRecoveryLoadFromEntry(entry);
      }
      if (isToday && _needsHealthRecoveryLoadFallback(summary)) {
        localSummary = await HealthRecoveryLoadService().fetchSummary(
          selectedDay,
          forceRefresh: force,
        );
        summary = _mergeHealthRecoveryLoad(summary, localSummary);
      }
      if (!mounted) return;
      _healthRecoveryLoadCache[selectedDay] = summary;
      if (_healthRecoveryLoadCache.length > 21) {
        final keys = _healthRecoveryLoadCache.keys.toList()..sort();
        while (_healthRecoveryLoadCache.length > 21 && keys.isNotEmpty) {
          _healthRecoveryLoadCache.remove(keys.removeAt(0));
        }
      }
      setState(() {
        _applyHealthRecoveryLoad(summary);
        _healthRecoveryLoadLoadingDate = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _healthRecoveryLoad = null;
        _healthRecoveryLoadLoading = false;
        _healthRecoveryLoadLoadingDate = null;
      });
    } finally {
      if (!mounted) return;
      if (_healthRecoveryLoadLoading &&
          _healthRecoveryLoadLoadingDate == selectedDay) {
        setState(() {
          _healthRecoveryLoadLoading = false;
          _healthRecoveryLoadLoadingDate = null;
        });
      }
    }
  }

  Future<void> _loadFitbitActivity({int attempt = 0}) async {
    if (_fitbitActivityLoading) return;
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitActivity(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() {
        _fitbitActivity = null;
        _fitbitActivityLoading = false;
        _fitbitLinked = false;
      });
      return;
    }

    if (!_hasFitbitActivityWidget) return;
    setState(() => _fitbitActivityLoading = true);
    try {
      await _loadFitbitStatus();
      if (!_fitbitLinked) {
        if (!mounted) return;
        setState(() {
          _fitbitActivity = null;
          _fitbitActivityLoading = false;
        });
        return;
      }
      final summary = await FitbitActivityService().fetchActivity(
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      );
      if (!mounted) return;
      setState(() {
        _fitbitActivity = summary;
        _fitbitActivityLast = summary;
        _fitbitActivityLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fitbitActivity = null;
        _fitbitActivityLoading = false;
      });
    } finally {
      if (!mounted) return;
      if (_fitbitActivityLoading) {
        setState(() => _fitbitActivityLoading = false);
      }
    }
  }

  Future<void> _loadFitbitHeart({int attempt = 0}) async {
    if (_fitbitHeartLoading) return;
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitHeart(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() {
        _fitbitHeart = null;
        _fitbitHeartLoading = false;
        _fitbitLinked = false;
      });
      return;
    }

    if (!_hasFitbitHeartWidget) return;
    setState(() => _fitbitHeartLoading = true);
    try {
      await _loadFitbitStatus();
      if (!_fitbitLinked) {
        if (!mounted) return;
        setState(() {
          _fitbitHeart = null;
          _fitbitHeartLoading = false;
        });
        return;
      }
      final summary = await FitbitHeartService().fetchSummary(
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      );
      if (!mounted) return;
      setState(() {
        _fitbitHeart = summary;
        _fitbitHeartLast = summary;
        _fitbitHeartLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fitbitHeart = null;
        _fitbitHeartLoading = false;
      });
    } finally {
      if (!mounted) return;
      if (_fitbitHeartLoading) {
        setState(() => _fitbitHeartLoading = false);
      }
    }
  }

  Future<void> _loadFitbitSleep({int attempt = 0}) async {
    if (_fitbitSleepLoading) return;
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitSleep(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() {
        _fitbitSleep = null;
        _fitbitSleepLoading = false;
        _fitbitLinked = false;
      });
      return;
    }

    if (!_hasFitbitSleepWidget) return;
    setState(() => _fitbitSleepLoading = true);
    try {
      await _loadFitbitStatus();
      if (!_fitbitLinked) {
        if (!mounted) return;
        setState(() {
          _fitbitSleep = null;
          _fitbitSleepLoading = false;
        });
        return;
      }
      final summary = await FitbitSleepService().fetchSummary(
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      );
      if (!mounted) return;
      setState(() {
        _fitbitSleep = summary;
        _fitbitSleepLast = summary;
        _fitbitSleepLoading = false;
      });
      final shouldUpdateTrend =
          (summary?.totalMinutesAsleep ?? 0) > 0 &&
          _shouldUpdateTrendForDate(_selectedDate);
      bool didUpdateTrend = false;
      if (shouldUpdateTrend) {
        didUpdateTrend = _tryUpdateTrendSleepForDate(
          _selectedDate,
          summary!.totalMinutesAsleep! / 60.0,
        );
      }
      final expectedSource = _trendSleepSourceForCurrentWidgets();
      if (_trendSleepSourceKey != expectedSource) {
        _loadTrendSleep(force: true);
      } else if (!didUpdateTrend && shouldUpdateTrend) {
        _loadTrendSleep(force: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fitbitSleep = null;
        _fitbitSleepLoading = false;
      });
    } finally {
      if (!mounted) return;
      if (_fitbitSleepLoading) {
        setState(() => _fitbitSleepLoading = false);
      }
    }
  }

  void _setFitbitLoadingFlags(bool value) {
    _fitbitActivityLoading = value;
    _fitbitHeartLoading = value;
    _fitbitSleepLoading = value;
    _fitbitVitalsLoading = value;
    _fitbitBodyLoading = value;
  }

  void _applyFitbitBundle(FitbitSummaryBundle? bundle) {
    _fitbitActivity = bundle?.activity;
    _fitbitHeart = bundle?.heart;
    _fitbitSleep = bundle?.sleep;
    _fitbitVitals = bundle?.vitals;
    _fitbitBody = bundle?.body;
    _fitbitActivityLast = bundle?.activity ?? _fitbitActivityLast;
    _fitbitHeartLast = bundle?.heart ?? _fitbitHeartLast;
    _fitbitSleepLast = bundle?.sleep ?? _fitbitSleepLast;
    _fitbitVitalsLast = bundle?.vitals ?? _fitbitVitalsLast;
    _fitbitBodyLast = bundle?.body ?? _fitbitBodyLast;
    _setFitbitLoadingFlags(false);
  }

  Future<void> _loadFitbitSummary({int attempt = 0, bool force = false}) async {
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isToday = selectedDay == todayOnly;
    if (!force &&
        _fitbitSummaryLoading &&
        _fitbitSummaryLoadingDate != null &&
        _fitbitSummaryLoadingDate == selectedDay) {
      return;
    }
    if (!force && _fitbitSummaryCache.containsKey(selectedDay)) {
      final cachedBundle = _fitbitSummaryCache[selectedDay];
      if (!mounted) return;
      setState(() {
        _applyFitbitBundle(cachedBundle);
        _fitbitSummaryLoadingDate = null;
      });
      final shouldUpdateTrend =
          isToday && (cachedBundle?.sleep?.totalMinutesAsleep ?? 0) > 0;
      bool didUpdateTrend = false;
      if (shouldUpdateTrend) {
        didUpdateTrend = _tryUpdateTrendSleepForDate(
          selectedDay,
          cachedBundle!.sleep!.totalMinutesAsleep! / 60.0,
        );
      }
      final expectedSource = _trendSleepSourceForCurrentWidgets();
      if (_trendSleepSourceKey != expectedSource) {
        _loadTrendSleep(force: true);
      } else if (!didUpdateTrend && shouldUpdateTrend) {
        _loadTrendSleep(force: true);
      }
      return;
    }

    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitSummary(attempt: attempt + 1, force: force);
      }
      if (!mounted) return;
      setState(() {
        _fitbitSummaryCache.clear();
        _fitbitSummaryLoadingDate = null;
        _fitbitLinked = false;
        _fitbitActivity = null;
        _fitbitHeart = null;
        _fitbitSleep = null;
        _fitbitVitals = null;
        _fitbitBody = null;
        _setFitbitLoadingFlags(false);
      });
      return;
    }

    _fitbitSummaryLoading = true;
    _fitbitSummaryLoadingDate = selectedDay;
    try {
      await _loadFitbitStatus();
      if (!_fitbitLinked) {
        if (mounted) {
          setState(() {
            _setFitbitLoadingFlags(false);
            _fitbitSummaryLoadingDate = null;
          });
        }
        return;
      }

      // Always load Fitbit summaries when linked, even if widgets are currently hidden.

      setState(() {
        _setFitbitLoadingFlags(true);
      });

      try {
        if (!_fitbitLinked) {
          if (!mounted) return;
          setState(() {
            _fitbitActivity = null;
            _fitbitHeart = null;
            _fitbitSleep = null;
            _fitbitVitals = null;
            _fitbitBody = null;
            _setFitbitLoadingFlags(false);
            _fitbitSummaryLoadingDate = null;
          });
          return;
        }

        final bundle = await FitbitSummaryService().fetchSummary(
          selectedDay,
          forceRefresh: force,
        );
        if (!mounted) return;
        _fitbitSummaryCache[selectedDay] = bundle;
        if (_fitbitSummaryCache.length > 21) {
          final keys = _fitbitSummaryCache.keys.toList()..sort();
          while (_fitbitSummaryCache.length > 21 && keys.isNotEmpty) {
            _fitbitSummaryCache.remove(keys.removeAt(0));
          }
        }
        setState(() {
          _applyFitbitBundle(bundle);
          _fitbitSummaryLoadingDate = null;
        });
        final shouldUpdateTrend =
            isToday && (bundle?.sleep?.totalMinutesAsleep ?? 0) > 0;
        bool didUpdateTrend = false;
        if (shouldUpdateTrend) {
          didUpdateTrend = _tryUpdateTrendSleepForDate(
            selectedDay,
            bundle!.sleep!.totalMinutesAsleep! / 60.0,
          );
        }
        final expectedSource = _trendSleepSourceForCurrentWidgets();
        if (_trendSleepSourceKey != expectedSource) {
          _loadTrendSleep(force: true);
        } else if (!didUpdateTrend && shouldUpdateTrend) {
          _loadTrendSleep(force: true);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _setFitbitLoadingFlags(false);
          _fitbitSummaryLoadingDate = null;
        });
      }
    } finally {
      _fitbitSummaryLoading = false;
      if (_fitbitSummaryLoadingDate == selectedDay) {
        _fitbitSummaryLoadingDate = null;
      }
    }
  }

  Future<void> _loadFitbitVitals({int attempt = 0}) async {
    if (_fitbitVitalsLoading) return;
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitVitals(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() {
        _fitbitVitals = null;
        _fitbitVitalsLoading = false;
        _fitbitLinked = false;
      });
      return;
    }

    if (!_hasFitbitVitalsWidget) return;
    setState(() => _fitbitVitalsLoading = true);
    try {
      await _loadFitbitStatus();
      if (!_fitbitLinked) {
        if (!mounted) return;
        setState(() {
          _fitbitVitals = null;
          _fitbitVitalsLoading = false;
        });
        return;
      }
      final summary = await FitbitVitalsService().fetchSummary(
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      );
      if (!mounted) return;
      setState(() {
        _fitbitVitals = summary;
        _fitbitVitalsLast = summary;
        _fitbitVitalsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fitbitVitals = null;
        _fitbitVitalsLoading = false;
      });
    } finally {
      if (!mounted) return;
      if (_fitbitVitalsLoading) {
        setState(() => _fitbitVitalsLoading = false);
      }
    }
  }

  Future<void> _loadFitbitBody({int attempt = 0}) async {
    if (_fitbitBodyLoading) return;
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitBody(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() {
        _fitbitBody = null;
        _fitbitBodyLoading = false;
        _fitbitLinked = false;
      });
      return;
    }

    if (!_hasFitbitBodyWidget) return;
    setState(() => _fitbitBodyLoading = true);
    try {
      await _loadFitbitStatus();
      if (!_fitbitLinked) {
        if (!mounted) return;
        setState(() {
          _fitbitBody = null;
          _fitbitBodyLoading = false;
        });
        return;
      }
      final summary = await FitbitBodyService().fetchSummary(
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      );
      if (!mounted) return;
      setState(() {
        _fitbitBody = summary;
        _fitbitBodyLast = summary;
        _fitbitBodyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fitbitBody = null;
        _fitbitBodyLoading = false;
      });
    } finally {
      if (!mounted) return;
      if (_fitbitBodyLoading) {
        setState(() => _fitbitBodyLoading = false);
      }
    }
  }

  Future<void> _openWaterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WaterIntakeSheet(
        initialGoal: _waterGoal ?? 2.5,
        initialIntake: _waterIntake ?? 0,
        onSaved: _loadWater,
      ),
    );
  }

  Future<Map<DateTime, DailyMetricsEntry?>> _fetchMetricsRange(
    DateTime start,
    DateTime end,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return {};
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final days = <DateTime>[];
    var cursor = normalizedStart;
    while (!cursor.isAfter(normalizedEnd)) {
      days.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    final fetched = await DailyMetricsApi.fetchRange(
      userId: userId,
      start: normalizedStart,
      end: normalizedEnd,
    );
    final trainingCaloriesService = TrainingCaloriesService();
    final map = <DateTime, DailyMetricsEntry?>{};
    for (final d in days) {
      final entry = fetched[d];
      if (entry != null) {
        map[d] = entry;
      } else {
        // Fallback: pull local data for that specific day if the backend has nothing.
        final steps = await StepsService().fetchStepsForDay(d);
        final sleep = await SleepService().fetchSleepForDay(d);
        final baseCalories = await CaloriesService().fetchCaloriesForDay(d);
        final trainingCalories = await trainingCaloriesService
            .fetchEstimatedCaloriesForDay(d);
        final calories = baseCalories + trainingCalories;
        final water = await WaterService().getIntakeForDay(d);
        final any = steps > 0 || sleep > 0 || calories > 0 || water > 0;
        map[d] = any
            ? DailyMetricsEntry(
                entryDate: d,
                steps: steps,
                sleepHours: sleep,
                calories: calories,
                waterLiters: water,
              )
            : null;
      }
    }

    // Inject today's local readings when the range includes today, since DB may not be updated yet.
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final includesToday =
        !todayKey.isBefore(normalizedStart) && !todayKey.isAfter(normalizedEnd);
    if (includesToday) {
      final current = map[todayKey];
      final localSteps = await StepsService().fetchTodaySteps();
      final localSleep = await SleepService().fetchSleepHoursLast24h();
      final localBaseCalories = await CaloriesService().fetchTodayCalories();
      final localTrainingCalories = await trainingCaloriesService
          .fetchEstimatedCaloriesForDay(todayKey);
      final localCalories = localBaseCalories + localTrainingCalories;
      final manualDisplayTotals = await CaloriesService()
          .getManualTotalDisplayEntries();
      final manualTodayCalories = manualDisplayTotals[todayKey];
      final localWater = await WaterService().getIntakeForDay(todayKey);
      final currentSleep = current?.sleepHours;
      final resolvedSleep = (currentSleep != null && currentSleep > 0)
          ? currentSleep
          : localSleep;
      final resolvedCalories =
          manualTodayCalories ??
          (localCalories > 0 ? localCalories : (current?.calories ?? 0));
      map[todayKey] = DailyMetricsEntry(
        entryDate: todayKey,
        steps: current?.steps ?? localSteps,
        sleepHours: resolvedSleep,
        calories: resolvedCalories,
        waterLiters: current?.waterLiters ?? localWater,
      );
    }
    return map;
  }

  Future<void> _loadWeeklySteps() async {
    setState(() {
      _weeklyStepsLoading = true;
    });
    try {
      final anchor = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final endOfWeek = monday.add(const Duration(days: 6));
      var end = anchor.isBefore(todayOnly) ? anchor : todayOnly;
      if (end.isAfter(endOfWeek)) {
        end = endOfWeek;
      }
      if (end.isBefore(monday)) {
        end = monday;
      }

      final metrics = await _fetchMetricsRange(monday, end);
      int total = 0;
      if (metrics.isNotEmpty) {
        total = metrics.values.fold<int>(
          0,
          (sum, entry) => sum + (entry?.steps ?? 0),
        );
      } else {
        final data = await StepsService().fetchDailySteps(
          start: monday,
          end: end,
        );
        total = data.values.fold<int>(0, (sum, val) => sum + val);
      }
      final daysCount = end.difference(monday).inDays + 1;
      if (!mounted) return;
      setState(() {
        _weeklySteps = total;
        _weeklyDaysCount = daysCount.clamp(1, 7);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weeklySteps = null;
        _weeklyDaysCount = 7;
      });
    } finally {
      if (mounted) {
        setState(() => _weeklyStepsLoading = false);
      }
    }
  }

  DateTime _trendWeekStartFor(DateTime anchor) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  String _trendSleepSourceForCurrentWidgets() {
    if (_hasWhoopSleepWidget && _whoopLinked) return 'whoop';
    if (_hasFitbitSleepWidget && _fitbitLinked) return 'fitbit';
    return 'default';
  }

  Future<void> _loadTrendSleep({bool force = false}) async {
    final reqId = ++_trendSleepReqId;
    try {
      final anchor = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final start = _trendWeekStartFor(anchor);
      final end = start.add(const Duration(days: 6)); // Mon-Sun
      final sourceKey = _trendSleepSourceForCurrentWidgets();
      final userId = await AccountStorage.getUserId();
      if (reqId != _trendSleepReqId) return;
      final cacheKey = userId == null || userId == 0
          ? null
          : _trendSleepCacheKey(
              userId: userId,
              sourceKey: sourceKey,
              weekStart: start,
            );
      if (!force && cacheKey != null) {
        final cached = _readTrendSleepWeekCache(cacheKey);
        if (cached != null) {
          _activeTrendSleepCacheKey = cacheKey;
          if (!mounted || reqId != _trendSleepReqId) return;
          setState(() {
            _trendWeekStart = start;
            _trendSleep = cached;
            _trendSleepSourceKey = sourceKey;
            _trendSleepLoading = false;
          });
          return;
        }
      }
      final sourceChanged = _trendSleepSourceKey != sourceKey;
      if (!force &&
          !sourceChanged &&
          _trendWeekStart != null &&
          _trendWeekStart == start) {
        _activeTrendSleepCacheKey = cacheKey;
        if (mounted && reqId == _trendSleepReqId) {
          setState(() => _trendSleepLoading = false);
        }
        return;
      }
      if (mounted && reqId == _trendSleepReqId) {
        setState(() => _trendSleepLoading = true);
      }
      final now = DateTime.now();
      final todayKey = DateTime(now.year, now.month, now.day);
      final dayKeys = List.generate(7, (i) {
        final d = DateTime(
          start.year,
          start.month,
          start.day,
        ).add(Duration(days: i));
        return DateTime(d.year, d.month, d.day);
      });
      List<double> days = const [];
      if (sourceKey == 'whoop') {
        final data = await WhoopSleepService().fetchDailySleepFromDb(
          start: start,
          end: end,
        );
        if (reqId != _trendSleepReqId) return;
        final selectedKey = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        var whoopToday = 0.0;
        if (userId != null && userId != 0) {
          whoopToday =
              WhoopWidgetDataService.cachedSleepHoursForDate(
                userId: userId,
                date: todayKey,
              ) ??
              0.0;
        }
        if (selectedKey == todayKey && (_whoopSleepHours ?? 0) > 0) {
          whoopToday = _whoopSleepHours!;
        } else {
          final localToday = _whoopSnapshotCache[todayKey]?.sleepHours;
          if (localToday != null && localToday > 0) {
            whoopToday = localToday;
          }
        }
        if (dayKeys.contains(todayKey) &&
            selectedKey == todayKey &&
            whoopToday <= 0) {
          try {
            final liveToday = await WhoopWidgetDataService().fetchForDate(
              todayKey,
            );
            if (reqId != _trendSleepReqId) return;
            final liveHours = liveToday.sleepHours;
            if (liveHours != null && liveHours > 0) {
              whoopToday = liveHours;
              _whoopSnapshotCache[todayKey] = liveToday;
              if (_whoopSnapshotCache.length > 21) {
                final keys = _whoopSnapshotCache.keys.toList()..sort();
                while (_whoopSnapshotCache.length > 21 && keys.isNotEmpty) {
                  _whoopSnapshotCache.remove(keys.removeAt(0));
                }
              }
              if (userId != null && userId != 0) {
                WhoopWidgetDataService.cacheSleepHoursForDate(
                  userId: userId,
                  date: todayKey,
                  sleepHours: liveHours,
                );
              }
            }
          } catch (_) {}
        }
        if (dayKeys.contains(todayKey) && whoopToday <= 0) {
          whoopToday =
              await WhoopSleepService().fetchSleepHoursForDay(todayKey) ?? 0.0;
          if (reqId != _trendSleepReqId) return;
          if (whoopToday > 0 && userId != null && userId != 0) {
            WhoopWidgetDataService.cacheSleepHoursForDate(
              userId: userId,
              date: todayKey,
              sleepHours: whoopToday,
            );
          }
        }
        days = dayKeys.map((key) {
          if (key == todayKey) return whoopToday;
          return data[key] ?? 0.0;
        }).toList();
      } else {
        final sleepToday = await SleepService().fetchSleepHoursLast24h();
        if (reqId != _trendSleepReqId) return;
        var usedFitbit = false;
        if (sourceKey == 'fitbit') {
          final data = await FitbitDailyMetricsDbService().fetchRange(
            start: start,
            end: end,
          );
          if (reqId != _trendSleepReqId) return;
          if (data.isNotEmpty) {
            int? _int(dynamic v) {
              if (v == null) return null;
              if (v is int) return v;
              if (v is num) return v.toInt();
              return int.tryParse(v.toString());
            }

            days = dayKeys.map((key) {
              if (key == todayKey) return sleepToday;
              final row = data[key];
              final minutesAsleep = _int(row?["sleep_minutes_asleep"]);
              final minutes = (minutesAsleep != null && minutesAsleep > 0)
                  ? minutesAsleep
                  : 0;
              return minutes > 0 ? minutes / 60.0 : 0.0;
            }).toList();

            usedFitbit = days.any((v) => v > 0);
          }
        }

        if (!usedFitbit) {
          final metrics = await _fetchMetricsRange(start, end);
          if (reqId != _trendSleepReqId) return;
          if (metrics.isNotEmpty) {
            days = dayKeys.map((key) {
              if (key == todayKey) return sleepToday;
              final entry = metrics[key];
              return (entry?.sleepHours ?? 0.0).toDouble();
            }).toList();
          } else {
            days = dayKeys.map((key) {
              if (key == todayKey) return sleepToday;
              return 0.0;
            }).toList();
          }
        }
      }
      if (reqId != _trendSleepReqId) return;
      final hasData = days.any((v) => v > 0);
      final resolved = hasData ? days : const <double>[];
      if (cacheKey != null) {
        _writeTrendSleepWeekCache(cacheKey, resolved);
        _activeTrendSleepCacheKey = cacheKey;
      } else {
        _activeTrendSleepCacheKey = null;
      }
      if (!mounted || reqId != _trendSleepReqId) return;
      setState(() {
        _trendWeekStart = start;
        _trendSleep = resolved;
        _trendSleepSourceKey = sourceKey;
      });
    } catch (_) {
      if (!mounted || reqId != _trendSleepReqId) return;
      setState(() => _trendSleep = const []);
    } finally {
      if (mounted && reqId == _trendSleepReqId) {
        setState(() => _trendSleepLoading = false);
      }
    }
  }

  Future<void> _loadTrendCalories({bool force = false}) async {
    final reqId = ++_trendCaloriesReqId;
    try {
      final anchor = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final start = _trendWeekStartFor(anchor);
      final end = start.add(const Duration(days: 6)); // Mon-Sun
      final userId = await AccountStorage.getUserId();
      final cacheKey = userId == null || userId == 0
          ? null
          : _trendCaloriesCacheKey(userId: userId, weekStart: start);
      if (!force && cacheKey != null) {
        final cached = _readTrendCaloriesWeekCache(cacheKey);
        if (cached != null) {
          _activeTrendCaloriesCacheKey = cacheKey;
          if (mounted && reqId == _trendCaloriesReqId) {
            setState(() {
              _trendWeekStart = start;
              _trendCaloriesLoadedWeekStart = start;
              _trendCalories = cached;
              _trendCaloriesLoading = false;
            });
          }
          return;
        }
      }
      if (!force &&
          _trendCaloriesLoadedWeekStart != null &&
          _trendCaloriesLoadedWeekStart == start) {
        _activeTrendCaloriesCacheKey = cacheKey;
        if (mounted && reqId == _trendCaloriesReqId) {
          setState(() => _trendCaloriesLoading = false);
        }
        return;
      }
      if (mounted && reqId == _trendCaloriesReqId) {
        setState(() => _trendCaloriesLoading = true);
      }
      final dayKeys = List.generate(7, (i) {
        final d = DateTime(
          start.year,
          start.month,
          start.day,
        ).add(Duration(days: i));
        return DateTime(d.year, d.month, d.day);
      });
      final metrics = await _fetchMetricsRange(start, end);
      var days = List.generate(7, (i) {
        final key = dayKeys[i];
        final entry = metrics[key];
        return (entry?.calories ?? 0).toDouble();
      });

      // Only pull HealthKit/Health Connect for current day; keep DB for past days.
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      final todayIdx = dayKeys.indexOf(todayKey);
      if (todayIdx >= 0) {
        final manualDisplayTotals = await CaloriesService()
            .getManualTotalDisplayEntries();
        final manualTodayCalories = manualDisplayTotals[todayKey];
        final baseCalories = await CaloriesService().fetchTodayCalories();
        final trainingCalories = await TrainingCaloriesService()
            .fetchEstimatedCaloriesForDay(todayKey);
        final todayCalories =
            manualTodayCalories ?? (baseCalories + trainingCalories);
        if (todayCalories > 0) {
          final next = List<double>.from(days);
          next[todayIdx] = todayCalories.toDouble();
          days = next;
        }
      }
      final hasData = days.any((v) => v > 0);
      final resolved = hasData ? days : const <double>[];
      if (cacheKey != null) {
        _writeTrendCaloriesWeekCache(cacheKey, resolved);
        _activeTrendCaloriesCacheKey = cacheKey;
      } else {
        _activeTrendCaloriesCacheKey = null;
      }
      if (!mounted) return;
      if (reqId != _trendCaloriesReqId) return;
      setState(() {
        _trendWeekStart = start;
        _trendCaloriesLoadedWeekStart = start;
        _trendCalories = resolved;
      });
    } catch (_) {
      if (!mounted) return;
      if (reqId != _trendCaloriesReqId) return;
      setState(() => _trendCalories = const []);
    } finally {
      if (mounted && reqId == _trendCaloriesReqId) {
        setState(() => _trendCaloriesLoading = false);
      }
    }
  }

  Future<void> _loadGoals() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _stepsGoal = sp.getInt(_stepsGoalKey) ?? 10000;
      _sleepGoal = sp.getDouble(_sleepGoalKey) ?? 8.0;
      _caloriesGoal = sp.getInt(_caloriesGoalKey) ?? 500;
    });
  }

  Future<num?> _promptGoal({
    required String title,
    required String label,
    required num initial,
    required bool allowDecimal,
  }) async {
    final controller = TextEditingController(text: initial.toString());
    return showDialog<num>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: allowDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final raw = controller.text.trim();
                if (raw.isEmpty) {
                  Navigator.of(ctx).pop();
                  return;
                }
                final parsed = double.tryParse(raw);
                if (parsed == null) {
                  Navigator.of(ctx).pop();
                  return;
                }
                Navigator.of(ctx).pop(allowDecimal ? parsed : parsed.toInt());
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editStepsGoal() async {
    final current = _stepsGoal ?? 10000;
    final res = await _promptGoal(
      title: "Steps goal",
      label: "Steps per day",
      initial: current,
      allowDecimal: false,
    );
    if (res != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_stepsGoalKey, res.toInt());
      if (!mounted) return;
      setState(() => _stepsGoal = res.toInt());
    }
  }

  Future<void> _editSleepGoal() async {
    final current = _sleepGoal ?? 8.0;
    final res = await _promptGoal(
      title: "Sleep goal",
      label: "Hours per night",
      initial: current,
      allowDecimal: true,
    );
    if (res != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(_sleepGoalKey, res.toDouble());
      if (!mounted) return;
      setState(() => _sleepGoal = res.toDouble());
    }
  }

  Future<void> _editCaloriesGoal() async {
    final current = _caloriesGoal ?? 500;
    final res = await _promptGoal(
      title: "Calories burn goal",
      label: "kcal per day",
      initial: current,
      allowDecimal: false,
    );
    if (res != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_caloriesGoalKey, res.toInt());
      if (!mounted) return;
      setState(() => _caloriesGoal = res.toInt());
    }
  }

  List<double> _trendSleepForDisplay() {
    var out = _trendSleep.isEmpty ? <double>[] : List<double>.from(_trendSleep);
    if (!_isToday()) return out;
    final start = _trendWeekStart ?? _trendWeekStartFor(_selectedDate);
    final idx = _dayKey(_selectedDate).difference(start).inDays;
    if (idx < 0 || idx > 6) return out;

    double? liveHours;
    final source = _trendSleepSourceForCurrentWidgets();
    if (source == 'whoop') {
      final todayKey = _dayKey(_selectedDate);
      liveHours = _whoopSleepHours ?? _whoopSnapshotCache[todayKey]?.sleepHours;
    } else if (source == 'fitbit') {
      final minutes = _fitbitSleep?.totalMinutesAsleep;
      liveHours = (minutes != null && minutes > 0) ? minutes / 60.0 : null;
    } else {
      liveHours = _sleepHours;
    }
    if (liveHours == null || liveHours <= 0) return out;

    if (out.isEmpty) {
      out = List<double>.filled(7, 0.0);
    } else if (out.length < 7) {
      out = [...out, ...List<double>.filled(7 - out.length, 0.0)];
    }
    out[idx] = liveHours;
    return out;
  }

  Future<void> _loadUserInfo() async {
    final storedAvatarRaw = await AccountStorage.getAvatarUrl();
    final storedAvatar =
        (storedAvatarRaw != null && storedAvatarRaw.trim().isNotEmpty)
        ? storedAvatarRaw
        : null;
    final storedAvatarPath = await AccountStorage.getAvatarPath();
    final storedName = await AccountStorage.getName();
    final userId = await AccountStorage.getUserId();

    if (mounted) {
      // Show whatever we already have immediately to avoid placeholder flicker.
      setState(() {
        _avatarUrl = storedAvatar;
        _avatarPath = storedAvatarPath;
        _displayName = storedName;
      });
    }

    String? fetchedName = storedName;
    String? fetchedAvatar = storedAvatar;
    double? fetchedHeight;
    double? fetchedWeight;

    if (userId != null) {
      try {
        final profile = await ProfileApi.fetchProfile(userId);
        final resolvedName = _resolveDisplayName(profile);
        final remoteAvatar = profile["avatar_url"]?.toString();
        final height = profile["height_cm"];
        final weight = profile["weight_kg"];
        if (resolvedName != null && resolvedName.trim().isNotEmpty) {
          fetchedName = resolvedName;
        }
        if (remoteAvatar != null && remoteAvatar.trim().isNotEmpty) {
          fetchedAvatar = remoteAvatar;
        }
        if (height != null) {
          fetchedHeight = double.tryParse(height.toString());
        }
        if (weight != null) {
          fetchedWeight = double.tryParse(weight.toString());
        }
      } catch (_) {
        // Ignore and fallback to stored values
      }
    }

    if (!mounted) return;
    if (fetchedName != null &&
        fetchedName.trim().isNotEmpty &&
        fetchedName != storedName) {
      await AccountStorage.setName(fetchedName);
    }
    setState(() {
      _avatarUrl = fetchedAvatar;
      _avatarPath = storedAvatarPath;
      _displayName = fetchedName;
      _heightCm = fetchedHeight;
      _weightKg = fetchedWeight;
    });

    await _loadBodyMeasurements();
  }

  String? _resolveDisplayName(Map<String, dynamic> profile) {
    final firstName = profile["first_name"]?.toString().trim() ?? "";
    final lastName = profile["last_name"]?.toString().trim() ?? "";
    final joined = [firstName, lastName].where((s) => s.isNotEmpty).join(" ");
    if (joined.isNotEmpty) return joined;

    final fullName = profile["full_name"]?.toString().trim() ?? "";
    if (fullName.isNotEmpty) return fullName;

    final name = profile["name"]?.toString().trim() ?? "";
    if (name.isNotEmpty) return name;

    final username = profile["username"]?.toString().trim() ?? "";
    if (username.isNotEmpty) return username;

    return null;
  }

  Future<void> _loadBodyMeasurements() async {
    final userId = await AccountStorage.getUserId();
    final key = userId == null
        ? "body_measurements"
        : "body_measurements_u$userId";
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map<String, dynamic>) {
          final height = first["height_cm"];
          final weight = first["weight_kg"];
          if (!mounted) return;
          setState(() {
            if (height != null) {
              _heightCm = double.tryParse(height.toString()) ?? _heightCm;
            }
            if (weight != null) {
              _weightKg = double.tryParse(weight.toString()) ?? _weightKg;
            }
          });
        }
      }
    } catch (_) {
      // ignore parse errors
    }
  }

  Future<void> _loadNews() async {
    try {
      // Try to fetch from server first
      final items = await NewsApi.fetchNews(limit: 10);
      if (!mounted) return;
      setState(() {
        _news = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      // Network failed, try loading from cache
      try {
        final cached = await NewsApi.fetchNewsFromCache();
        if (!mounted) return;
        setState(() {
          _news = cached;
          _loading = false;
          _error = null; // Don't show error if we have cached data
        });
      } catch (_) {
        // No cache available
        if (!mounted) return;
        setState(() {
          _error = null; // Don't show error, just show empty state
          _loading = false;
        });
      }
    }
  }

  void _openAnnouncements() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AnnouncementsPage(items: _news)));
  }

  void _openTrainingPage() {
    widget.onNavigateToTab?.call(1);
  }

  void _openDietPage() {
    widget.onNavigateToTab?.call(2);
  }

  Widget _buildAvatar() {
    // Prefer stored file if present
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      final file = File(_avatarPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person, color: Colors.white),
        );
      }
    }

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, color: Colors.white),
      );
    }

    return const Center(child: Icon(Icons.person, color: Colors.white));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final locale = AppLocalizations.of(context).locale.languageCode;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final slides = _news.isEmpty
        ? [
            NewsSlide(
              title: t("dash_stay_tuned"),
              subtitle: t("dash_announce_here"),
              tag: t("dash_news_tag"),
              color: const Color(0xFF6A5AE0),
              onTap: _openAnnouncements,
            ),
          ]
        : _news
              .map(
                (n) => NewsSlide(
                  title: n.title,
                  subtitle: n.subtitle,
                  tag: n.tag,
                  color: _colorForTag(n.tag),
                  onTap: _openAnnouncements,
                ),
              )
              .toList();

    final averageSleep =
        _sleepHours ??
        (_mockSleepHours.isEmpty
            ? 0
            : _mockSleepHours.reduce((a, b) => a + b) / _mockSleepHours.length);
    final weeklySteps =
        _weeklySteps ??
        (_mockSteps.isEmpty ? 0 : _mockSteps.reduce((a, b) => a + b));
    final todaysStepsDisplay = _todaySteps ?? 0;
    final todaysCaloriesDisplay = _todayCalories ?? 0;
    final waterGoal = _waterGoal ?? 2.5;
    final waterIntake = _waterIntake ?? 0;
    final weeklyStepGoalTotal = (_stepsGoal ?? 10000) * 7;
    final weeklyProgress = weeklyStepGoalTotal == 0
        ? 0.0
        : (weeklySteps / weeklyStepGoalTotal).clamp(0.0, 2.0);
    final metricsLoading =
        _stepsLoading || _sleepLoading || _caloriesLoading || _waterLoading;
    final noEntriesForSelectedDate =
        !_isToday() &&
        !metricsLoading &&
        _todaySteps == null &&
        _sleepHours == null &&
        _todayCalories == null &&
        _waterIntake == null;
    final todayOnly = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final selectedDayOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isYesterday =
        selectedDayOnly == todayOnly.subtract(const Duration(days: 1));
    final relativeDateLabel = _isToday()
        ? t("date_today")
        : isYesterday
        ? t("date_yesterday")
        : DateFormat('MMM d, y', locale).format(_selectedDate);
    final bool isCurrentDay = _isToday();
    final bool showTrainingSub = isCurrentDay && !_exerciseLoading;

    final listView = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t("dash_welcome_back"),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayName == null || _displayName!.isEmpty
                        ? t("dash_dashboard")
                        : t("dash_hi_name").replaceAll("{name}", _displayName!),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_streakCount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _streakLoading
                          ? "Streak: …"
                          : "Streak: ${(_streakCount ?? 0)}${(_streakCount ?? 0) > 0 ? " 🔥" : ""}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    (_avatarUrl == null || _avatarUrl!.isEmpty) &&
                        (_avatarPath == null || _avatarPath!.isEmpty)
                    ? const LinearGradient(
                        colors: [Color(0xFF35B6FF), AppColors.accent],
                      )
                    : null,
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: ClipOval(child: _buildAvatar()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const LinearProgressIndicator(
            color: AppColors.accent,
            backgroundColor: Colors.white12,
            minHeight: 2,
          ),
        if (noEntriesForSelectedDate)
          CardContainer(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Text(
                  t("no_entries"),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          )
        else ...[
          if (!_isToday() &&
              _todaySteps == null &&
              _sleepHours == null &&
              _todayCalories == null &&
              _waterIntake == null)
            CardContainer(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: Text(
                    t("no_entries"),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          if (_error != null)
            CardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t("dash_news_tag"),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            IgnorePointer(
              ignoring: _wiggling,
              child: NewsCarousel(slides: slides),
            ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: (_wiggling || !isCurrentDay) ? null : _openTrainingPage,
          child: CardContainer(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    height: 72,
                    width: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 8,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.white.withOpacity(0.08),
                          ),
                        ),
                        CircularProgressIndicator(
                          value: (_exerciseTotal != null && _exerciseTotal != 0)
                              ? ((_exerciseCompleted ?? 0) /
                                        (_exerciseTotal!.toDouble()))
                                    .clamp(0.0, 1.0)
                              : 0.0,
                          strokeWidth: 8,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        Center(
                          child: _exerciseLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      (_exerciseCompleted ?? 0).toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      _exerciseTotal == null
                                          ? "—"
                                          : "/ ${_exerciseTotal.toString()}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Training progress",
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        if (showTrainingSub)
                          Text(
                            ((_exerciseTotal ?? 0) > 0 &&
                                    (_exerciseCompleted ?? 0) >=
                                        (_exerciseTotal ?? 0))
                                ? "Done for the week"
                                : (_exerciseTotal == null &&
                                      _nextTrainingDayLabel == null &&
                                      !_nextTrainingDayAllDone)
                                ? t("dash_exercise_unavailable")
                                : _nextTrainingDayAllDone
                                ? "Done for the week"
                                : "Next up: ${(_nextTrainingDayLabel ?? "…")}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        if (_exerciseProgramMode == "old")
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "Old program",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!noEntriesForSelectedDate) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (_wiggling || !isCurrentDay) ? null : _openDietPage,
            child: DietProgressCard(
              loading: _dietProgressLoading,
              consumedCalories: _dietConsumedCalories,
              targetCalories: _dietTargetCalories,
              dayType: _dietDayType,
            ),
          ),
          const SizedBox(height: 12),
          TaqaScoreWidget(
            score: _taqaScore,
            loading: _taqaScoreLoading,
            provider: _taqaScore?.provider,
            scoreDayLabel: _isTaqaTodaySelection()
                ? t("dash_taqa_yesterday_scores")
                : DateFormat(
                    'dd/MM',
                    locale,
                  ).format(_taqaScoreDateForSelection()),
            emptyMessage: _isTaqaTodaySelection()
                ? t("taqa_no_data_yesterday_hint")
                : t("taqa_no_data"),
            onTap: !_isTaqaTodaySelection()
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaqaScoreDetailPage(
                          initialDate: _taqaScoreDateForSelection(),
                        ),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              Widget buildTileForKey(String key) {
                switch (key) {
                  case 'steps':
                    return StatCard(
                      title: t("dash_today_steps"),
                      value: (_stepsLoading && _todaySteps == null)
                          ? "…"
                          : "${todaysStepsDisplay.toString()}",
                      subtitle:
                          "${t("dash_goal")} ${(_stepsGoal ?? 10000).toString()}",
                      icon: Icons.directions_walk,
                      accentColor: const Color(0xFF35B6FF),
                      footerRight: _stepsDelta == null
                          ? null
                          : Row(
                              children: [
                                Icon(
                                  _stepsDelta! >= 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 12,
                                  color: _stepsDelta! >= 0
                                      ? const Color(0xFF4CD964)
                                      : const Color(0xFFFF8A00),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _stepsDelta!.abs().toString(),
                                  style: TextStyle(
                                    color: _stepsDelta! >= 0
                                        ? const Color(0xFF4CD964)
                                        : const Color(0xFFFF8A00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.directions_walk,
                                  size: 12,
                                  color: _stepsDelta! >= 0
                                      ? const Color(0xFF4CD964)
                                      : const Color(0xFFFF8A00),
                                ),
                              ],
                            ),
                      onTap: isCurrentDay
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const StepsDetailPage(),
                                ),
                              );
                              await _loadGoals();
                              await _loadSteps();
                            }
                          : null,
                    );
                  case 'sleep':
                    return StatCard(
                      title: t("dash_today_sleep"),
                      value: (_sleepLoading && _sleepHours == null)
                          ? "…"
                          : "${averageSleep.toStringAsFixed(1)} ${t("dash_unit_hrs")}",
                      subtitle:
                          "${t("dash_goal")} ${(_sleepGoal ?? 8.0).toStringAsFixed(1)} ${t("dash_unit_hrs")}",
                      icon: Icons.nights_stay,
                      accentColor: const Color(0xFF9B8CFF),
                      deltaPercent: _sleepDelta,
                      onTap: isCurrentDay
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SleepDetailPage(),
                                ),
                              );
                              await _loadGoals();
                              await _loadSleep();
                            }
                          : null,
                    );
                  case 'whoop_sleep':
                    return WhoopSleepCard(
                      loading: _isWhoopLoadingForSelectedDate(),
                      linked: _whoopLinked,
                      linkedKnown:
                          _whoopLinkedKnown || _whoopLinkedHint != null,
                      hours: _whoopSleepHours,
                      score: _whoopSleepScore,
                      goal: _sleepGoal,
                      delta: _whoopSleepDelta,
                      onTap: isCurrentDay
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SleepDetailPage(useWhoop: true),
                                ),
                              );
                            }
                          : null,
                    );
                  case 'whoop_recovery':
                    return WhoopRecoveryCard(
                      loading: _isWhoopLoadingForSelectedDate(),
                      linked: _whoopLinked,
                      score: _whoopRecovery,
                      delta: _whoopRecoveryDelta,
                      onTap: isCurrentDay
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WhoopRecoveryDetailPage(
                                    initialDate: _selectedDate,
                                  ),
                                ),
                              );
                            }
                          : null,
                    );
                  case 'whoop_cycle':
                    return WhoopCycleCard(
                      loading: _isWhoopLoadingForSelectedDate(),
                      linked: _whoopLinked,
                      strain: _whoopCycleStrain,
                      onTap: isCurrentDay
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WhoopCycleDetailPage(
                                    initialDate: _selectedDate,
                                  ),
                                ),
                              );
                            }
                          : null,
                    );
                  case 'whoop_body':
                    return WhoopBodyCard(
                      loading: _isWhoopLoadingForSelectedDate(),
                      linked: _whoopLinked,
                      weightKg: _whoopBodyWeightKg,
                      onTap: isCurrentDay
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const WhoopBodyDetailPage(),
                                ),
                              );
                            }
                          : null,
                    );
                  case 'strava_activities':
                    final stravaActivitiesValue = _stravaActivitiesLoading
                        ? '...'
                        : '${_stravaActivitiesCount ?? 0}';
                    const stravaOrange = Color(0xFFFF6A2A);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        StatCard(
                          title: "Strava Activities",
                          value: stravaActivitiesValue,
                          subtitle: "sessions done",
                          icon: Icons.directions_run,
                          accentColor: stravaOrange,
                          borderColor: stravaOrange,
                          borderWidth: 2.2,
                          onTap: isCurrentDay
                              ? () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const StravaDetailPage(
                                        kind: StravaDetailKind.activities,
                                      ),
                                    ),
                                  );
                                  await _loadStravaStatus();
                                }
                              : null,
                        ),
                        Positioned(
                          top: -10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stravaOrange,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/strava_logo_icon_170697.png',
                              height: 14,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    );
                  case 'water':
                    return WaterIntakeCard(
                      loading: _waterLoading && _waterIntake == null,
                      intakeLiters: waterIntake,
                      goalLiters: waterGoal,
                      deltaPercent: _waterDelta,
                      onTap: isCurrentDay ? _openWaterSheet : null,
                    );
                  case 'body':
                    return BodyMeasurementsCard(
                      heightCm: _heightCm,
                      weightKg: _weightKg,
                      onTap: isCurrentDay
                          ? () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => BodyMeasurementsSheet(
                                  initialHeightCm: _heightCm,
                                  initialWeightKg: _weightKg,
                                  onSaved: (res) {
                                    setState(() {
                                      if (res.heightCm != null)
                                        _heightCm = res.heightCm;
                                      if (res.weightKg != null)
                                        _weightKg = res.weightKg;
                                    });
                                  },
                                ),
                              );
                            }
                          : null,
                    );
                  case 'health_recovery_load':
                    final recoveryLoad = _healthRecoveryLoadLoading
                        ? (_healthRecoveryLoadLast ?? _healthRecoveryLoad)
                        : _healthRecoveryLoad;
                    final loading =
                        _healthRecoveryLoadLoading && recoveryLoad == null;
                    return HealthRecoveryLoadCard(
                      loading: loading,
                      restingHr: recoveryLoad?.restingHeartRate,
                      hrvMs: recoveryLoad?.hrvMs,
                      activeMinutes: recoveryLoad?.activeMinutes,
                      zones: recoveryLoad?.zones,
                      onTap: isCurrentDay
                          ? () async {
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => HealthRecoveryLoadSheet(
                                  summary: recoveryLoad,
                                  date: _selectedDate,
                                ),
                              );
                            }
                          : null,
                    );
                  case 'fitbit_activity':
                    final summary = _fitbitActivityLoading
                        ? (_fitbitActivityLast ?? _fitbitActivity)
                        : _fitbitActivity;
                    final loading = _fitbitActivityLoading && summary == null;
                    return FitbitDailyActivityCard(
                      loading: loading,
                      steps: summary?.steps,
                      distanceKm: summary?.distance,
                      calories: summary?.calories,
                      activeMinutes: summary?.activeMinutes,
                      onTap: (!isCurrentDay || summary == null)
                          ? null
                          : () async {
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => FitbitDailyActivitySheet(
                                  summary: summary,
                                  date: _selectedDate,
                                ),
                              );
                            },
                    );
                  case 'fitbit_heart':
                    final heart = _fitbitHeartLoading
                        ? (_fitbitHeartLast ?? _fitbitHeart)
                        : _fitbitHeart;
                    final loading = _fitbitHeartLoading && heart == null;
                    return FitbitHeartCard(
                      loading: loading,
                      restingHr: heart?.restingHr,
                      hrvRmssd: heart?.hrvRmssd,
                      vo2Max: heart?.vo2Max,
                      onTap: isCurrentDay
                          ? () async {
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => FitbitHeartSheet(
                                  restingHr: heart?.restingHr,
                                  hrvRmssd: heart?.hrvRmssd,
                                  vo2Max: heart?.vo2Max,
                                  zones: heart?.zones ?? const [],
                                  date: _selectedDate,
                                ),
                              );
                            }
                          : null,
                    );
                  case 'fitbit_sleep':
                    final sleep = _fitbitSleepLoading
                        ? (_fitbitSleepLast ?? _fitbitSleep)
                        : _fitbitSleep;
                    final loading = _fitbitSleepLoading && sleep == null;
                    return FitbitSleepCard(
                      loading: loading,
                      minutesAsleep: sleep?.totalMinutesAsleep,
                      minutesInBed: sleep?.totalTimeInBed,
                      goalMinutes: sleep?.sleepGoalMinutes,
                      onTap: isCurrentDay
                          ? () async {
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => FitbitSleepSheet(
                                  summary: sleep,
                                  date: _selectedDate,
                                ),
                              );
                            }
                          : null,
                    );
                  case 'fitbit_vitals':
                    final vitals = _fitbitVitalsLoading
                        ? (_fitbitVitalsLast ?? _fitbitVitals)
                        : _fitbitVitals;
                    final loading = _fitbitVitalsLoading && vitals == null;
                    return FitbitVitalsCard(
                      loading: loading,
                      spo2Percent: vitals?.spo2Percent,
                      skinTempC: vitals?.skinTempC,
                      breathingRate: vitals?.breathingRate,
                      ecgSummary: vitals?.ecgSummary,
                      ecgAvgHr: vitals?.ecgAvgHr,
                      onTap: isCurrentDay
                          ? () async {
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) =>
                                    FitbitVitalsSheet(summary: vitals),
                              );
                            }
                          : null,
                    );
                  case 'fitbit_body':
                    final body = _fitbitBodyLoading
                        ? (_fitbitBodyLast ?? _fitbitBody)
                        : _fitbitBody;
                    final loading = _fitbitBodyLoading && body == null;
                    return FitbitBodyCard(
                      loading: loading,
                      weightKg: body?.weightKg,
                      onTap: isCurrentDay
                          ? () async {
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => FitbitBodySheet(summary: body),
                              );
                            }
                          : null,
                    );
                  case 'calories':
                  default:
                    return StatCard(
                      title: t("dash_calories_burned"),
                      value: (_caloriesLoading && _todayCalories == null)
                          ? "…"
                          : "${todaysCaloriesDisplay.toString()} ${t("dash_unit_kcal")}",
                      subtitle:
                          "${t("dash_goal")} ${(_caloriesGoal ?? 500).toString()}",
                      icon: Icons.local_fire_department,
                      accentColor: const Color(0xFFFF8A00),
                      footerRight: _caloriesDelta == null
                          ? null
                          : Row(
                              children: [
                                Icon(
                                  _caloriesDelta! >= 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 12,
                                  color: _caloriesDelta! >= 0
                                      ? const Color(0xFF4CD964)
                                      : const Color(0xFFFF8A00),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${_caloriesDelta!.abs()} ${t("dash_unit_kcal")}",
                                  style: TextStyle(
                                    color: _caloriesDelta! >= 0
                                        ? const Color(0xFF4CD964)
                                        : const Color(0xFFFF8A00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                      onTap: isCurrentDay
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CaloriesDetailPage(),
                                ),
                              );
                              await _loadGoals();
                              await _loadCalories();
                            }
                          : null,
                    );
                }
              }

              final maxWidth = constraints.maxWidth;
              const crossAxisCount = 2;
              const spacing = 12.0;
              const aspectRatio = 1.10;
              final tileWidth = (maxWidth - spacing) / crossAxisCount;
              final tileHeight = tileWidth / aspectRatio;
              final rows = (_statOrder.length / crossAxisCount).ceil();
              final height = rows > 0
                  ? rows * tileHeight + (rows - 1) * spacing
                  : 0.0;

              return SizedBox(
                height: height,
                child: Stack(
                  children: [
                    for (int i = 0; i < _statOrder.length; i++)
                      AnimatedPositioned(
                        key: ValueKey(_statOrder[i]),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: (i % crossAxisCount) * (tileWidth + spacing),
                        top: (i ~/ crossAxisCount) * (tileHeight + spacing),
                        width: tileWidth,
                        height: tileHeight,
                        child: _buildStatTile(
                          _statOrder[i],
                          buildTileForKey(_statOrder[i]),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Insights cards temporarily disabled.
          if (false && _whoopLinked) ...[
            WhoopExtrasCard(
              onTap: _wiggling
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WhoopInsightsPage(
                            loading: _whoopLoading,
                            linked: _whoopLinked,
                            linkedKnown: _whoopLinkedKnown,
                            recoveryScore: _whoopRecovery,
                            weightKg: _whoopBodyWeightKg,
                            sleepHours: _whoopSleepHours,
                            sleepScore: _whoopSleepScore,
                            sleepGoal: _sleepGoal,
                            sleepDelta: _whoopSleepDelta,
                            cycleStrain: _whoopCycleStrain,
                            hideSleep: _statOrder.contains('whoop_sleep'),
                            hideRecovery: _statOrder.contains('whoop_recovery'),
                            hideCycle: _statOrder.contains('whoop_cycle'),
                            hideBody: _statOrder.contains('whoop_body'),
                          ),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 16),
          ],
          if (false && _fitbitLinked) ...[
            if (!(_statOrder.contains('fitbit_activity') &&
                _statOrder.contains('fitbit_heart') &&
                _statOrder.contains('fitbit_sleep') &&
                _statOrder.contains('fitbit_vitals') &&
                _statOrder.contains('fitbit_body'))) ...[
              FitbitExtrasCard(
                onTap: _wiggling
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FitbitInsightsPage(
                              activityLoading: _fitbitActivityLoading,
                              heartLoading: _fitbitHeartLoading,
                              sleepLoading: _fitbitSleepLoading,
                              vitals: _fitbitVitals,
                              vitalsLast: _fitbitVitalsLast,
                              body: _fitbitBody,
                              bodyLast: _fitbitBodyLast,
                              activity: _fitbitActivity,
                              activityLast: _fitbitActivityLast,
                              heart: _fitbitHeart,
                              heartLast: _fitbitHeartLast,
                              sleep: _fitbitSleep,
                              sleepLast: _fitbitSleepLast,
                              date: _selectedDate,
                              hideActivity: _statOrder.contains(
                                'fitbit_activity',
                              ),
                              hideHeart: _statOrder.contains('fitbit_heart'),
                              hideSleep: _statOrder.contains('fitbit_sleep'),
                              hideVitals: _statOrder.contains('fitbit_vitals'),
                              hideBody: _statOrder.contains('fitbit_body'),
                            ),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 16),
            ],
          ],
          ProgressMeter(
            title: t("dash_weekly_goal"),
            progress: weeklyProgress,
            targetLabel:
                "${t("dash_target")}: $weeklyStepGoalTotal ${t("dash_steps_week")}",
            trailingLabel: _weeklyStepsLoading
                ? t("dash_loading")
                : "$weeklySteps ${t("dash_steps_label")}",
            accentColor: const Color(0xFF35B6FF),
            onTap: (_wiggling || !isCurrentDay) ? null : _loadWeeklySteps,
          ),
          const SizedBox(height: 16),
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t("dash_7day_trends"),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TrendTile(
                        title: t("dash_sleep_hrs"),
                        data: _trendSleepForDisplay(),
                        loading: _trendSleepLoading,
                        accentColor: const Color(0xFF9B8CFF),
                        emptyLabel: t("dash_no_sleep_data"),
                        onTap: isCurrentDay ? _handleTrendSleepTap : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TrendTile(
                        title: t("dash_calories_scaled"),
                        data: _trendCalories.map((e) => e / 100).toList(),
                        loading: _trendCaloriesLoading,
                        accentColor: const Color(0xFFFF8A00),
                        emptyLabel: t("dash_no_calories_data"),
                        onTap: isCurrentDay ? _handleTrendCaloriesTap : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PlaceholderMetricCard(
            title: t("dash_fueling"),
            subtitle: t("dash_placeholder"),
            icon: Icons.restaurant_menu,
            accentColor: const Color(0xFF00BFA6),
          ),
          const SizedBox(height: 12),
          _PlaceholderMetricCard(
            title: t("dash_muscle"),
            subtitle: t("dash_placeholder"),
            icon: Icons.fitness_center,
            accentColor: const Color(0xFFFF8A00),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 60),
        ],
      ],
    );

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        notificationPredicate: (_) => isCurrentDay,
        onRefresh: (!_wiggling && isCurrentDay)
            ? () => _refreshAll(refreshStrava: false, refreshTaqaScore: false)
            : () async {},
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _stopWiggle,
          child: Stack(
            children: [
              listView,
              Positioned(
                left: 20,
                bottom: 20 + bottomInset,
                child: EditModeBubble(
                  visible: _wiggling && isCurrentDay,
                  onTap: _openWidgetLibrary,
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20 + bottomInset,
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedOpacity(
                    opacity: (!_wiggling && _wearableBubbleVisible) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedScale(
                      scale: (!_wiggling && _wearableBubbleVisible)
                          ? 1.0
                          : 0.96,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.watch,
                              size: 16,
                              color: Colors.white,
                            ),
                            if (_wearableBubbleType == 'apple') ...[
                              const SizedBox(width: 8),
                              Text(
                                "Apple Watch",
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20 + bottomInset,
                child: IgnorePointer(
                  ignoring: _wiggling,
                  child: AnimatedOpacity(
                    opacity: _wiggling ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    child: AnimatedScale(
                      scale: _wiggling ? 0.96 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: GestureDetector(
                        onTap: _openDateSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCurrentDay
                                        ? t("date_today")
                                        : DateFormat(
                                            'EEE',
                                            locale,
                                          ).format(_selectedDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMM d, y',
                                      locale,
                                    ).format(_selectedDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Backward-compatible alias for older references during hot reloads.
typedef _DashboardPageState = DashboardPageState;

class _PlaceholderMetricCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _PlaceholderMetricCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendTile extends StatelessWidget {
  final String title;
  final List<double> data;
  final bool loading;
  final Color accentColor;
  final String emptyLabel;
  final VoidCallback? onTap;

  const _TrendTile({
    required this.title,
    required this.data,
    required this.loading,
    required this.accentColor,
    required this.emptyLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (loading) {
      content = const Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (data.isEmpty) {
      content = Text(
        emptyLabel,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.white60),
      );
    } else {
      content = BarTrend(title: title, data: data, accentColor: accentColor);
    }
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}
