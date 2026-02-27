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
import '../../widgets/dashboard/edit_mode_bubble.dart';
import '../../widgets/dashboard/widget_library_sheet.dart';
import '../../screens/whoop_insights_page.dart';
import '../../screens/fitbit_insights_page.dart';
import '../../screens/whoop_recovery_detail_page.dart';
import '../../screens/whoop_cycle_detail_page.dart';
import '../../screens/whoop_body_detail_page.dart';
import '../../theme/app_theme.dart';
import '../../core/account_storage.dart';
import '../../services/auth/profile_service.dart';
import '../../services/metrics/daily_metrics_api.dart';
import '../../config/base_url.dart';
import '../../services/health/steps_service.dart';
import '../../services/health/sleep_service.dart';
import '../../services/whoop/whoop_sleep_service.dart';
import '../../services/whoop/whoop_widget_data_service.dart';
import '../../services/diet/calories_service.dart';
import '../../services/diet/diet_service.dart';
import '../../services/health/water_service.dart';
import '../../services/fitbit/fitbit_activity_service.dart';
import '../../services/fitbit/fitbit_heart_service.dart';
import '../../services/fitbit/fitbit_sleep_service.dart';
import '../../services/fitbit/fitbit_vitals_service.dart';
import '../../services/fitbit/fitbit_body_service.dart';
import '../../services/fitbit/fitbit_summary_service.dart';
import '../../screens/sleep_detail_page.dart';
import '../../screens/steps_detail_page.dart';
import '../../screens/calories_detail_page.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common/date_header.dart';
import '../../services/training/training_service.dart';
import '../../widgets/primary_button.dart';
import '../../screens/whoop_test_page.dart';
import 'dart:math' as math;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  AnimationController? _wiggleController;
  Animation<double>? _wiggleAnim;
  bool _wiggling = false;
  final List<String> _statOrder = ['steps', 'sleep', 'water', 'calories'];
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
  List<double> _trendSleep = const [];
  List<double> _trendCalories = const [];
  bool _trendSleepLoading = false;
  bool _trendCaloriesLoading = false;
  bool _whoopLinked = false;
  bool _whoopLinkedKnown = false;
  bool _whoopLoading = false;
  int? _whoopRecovery;
  double? _whoopSleepHours;
  int? _whoopSleepScore;
  int? _whoopSleepDelta;
  int? _whoopRecoveryDelta;
  double? _whoopCycleStrain;
  double? _whoopCycleStrainLast;
  double? _whoopBodyWeightKg;
  int _whoopReqId = 0;
  bool _fitbitLinked = false;
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
  DateTime _selectedDate = DateTime.now();
  int _weeklyDaysCount = 7;
  int? _exerciseTotal;
  int? _exerciseCompleted;
  bool _exerciseLoading = false;
  bool _exerciseLoadedOnce = false;
  String? _exerciseProgramMode;

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
    final next = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + deltaDays,
    );
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (next.isAfter(todayOnly)) return;
    setState(() {
      _selectedDate = next;
      _exerciseLoadedOnce = false;
      _exerciseTotal = null;
      _exerciseCompleted = null;
      // Keep existing Fitbit values while new date loads to avoid zero/empty flicker.
    });
    _loadSteps();
    _loadSleep();
    _loadCalories();
    _loadWater();
    _loadWeeklySteps();
    _loadTrendSleep();
    _loadTrendCalories();
    _loadExerciseProgress();
    _loadWhoopRecovery();
    _loadFitbitSummary();
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
    AccountStorage.accountChange.addListener(_onAccountChanged);
    AccountStorage.trainingChange.addListener(_onTrainingChanged);
    _loadStatOrder();
    _loadInitialData();
    _loadExerciseProgress();
  }

  void _onWhoopChanged() {
    _loadWhoopRecovery();
  }

  void _onAccountChanged() {
    _refreshAll();
    _loadExerciseProgress(force: true);
  }

  void _onTrainingChanged() {
    _loadExerciseProgress(force: true);
  }

  @override
  void dispose() {
    _wiggleController?.dispose();
    AccountStorage.whoopChange.removeListener(_onWhoopChanged);
    AccountStorage.accountChange.removeListener(_onAccountChanged);
    AccountStorage.trainingChange.removeListener(_onTrainingChanged);
    super.dispose();
  }

  void _ensureWiggle() {
    if (_wiggleController != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _wiggleController = controller;
    _wiggleAnim = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.linear),
    );
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
    ];
    if (_fitbitLinked) {
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
    if (_whoopLinked) {
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
  }

  Future<void> _loadStatOrder() async {
    final sp = await SharedPreferences.getInstance();
    final userId = await AccountStorage.getUserId();
    final key = userId == null ? "dash_stat_order" : "dash_stat_order_u$userId";
    final raw = sp.getString(key);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final next = decoded.map((e) => e.toString()).toList();
        final allowed = {
          'steps',
          'sleep',
          'water',
          'calories',
          'body',
          'fitbit_activity',
          'fitbit_heart',
          'fitbit_sleep',
          'fitbit_vitals',
          'fitbit_body',
          'whoop_sleep',
          'whoop_recovery',
          'whoop_cycle',
          'whoop_body',
        };
        final filtered = <String>[];
        for (final item in next) {
          if (allowed.contains(item) && !filtered.contains(item)) {
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
        setState(() {
          _statOrder
            ..clear()
            ..addAll(pruned);
        });
      }
    } catch (_) {
      // ignore parse errors
    }
  }

  bool get _useWhoop {
    return false;
  }

  bool get _hasFitbitActivityWidget => _statOrder.contains('fitbit_activity');
  bool get _hasFitbitHeartWidget => _statOrder.contains('fitbit_heart');
  bool get _hasFitbitSleepWidget => _statOrder.contains('fitbit_sleep');
  bool get _hasFitbitVitalsWidget => _statOrder.contains('fitbit_vitals');
  bool get _hasFitbitBodyWidget => _statOrder.contains('fitbit_body');
  bool get _hasWhoopSleepWidget => _statOrder.contains('whoop_sleep');
  bool get _hasAnyWhoopWidget =>
      _statOrder.contains('whoop_sleep') ||
      _statOrder.contains('whoop_recovery') ||
      _statOrder.contains('whoop_cycle') ||
      _statOrder.contains('whoop_body');

  Future<void> _saveStatOrder() async {
    final sp = await SharedPreferences.getInstance();
    final userId = await AccountStorage.getUserId();
    final key = userId == null ? "dash_stat_order" : "dash_stat_order_u$userId";
    await sp.setString(key, jsonEncode(_statOrder));
  }

  void _pruneDeviceWidgets() {
    var changed = false;
    if (!_fitbitLinked) {
      if (_statOrder.remove('fitbit_activity')) changed = true;
      if (_statOrder.remove('fitbit_heart')) changed = true;
      if (_statOrder.remove('fitbit_sleep')) changed = true;
      if (_statOrder.remove('fitbit_vitals')) changed = true;
      if (_statOrder.remove('fitbit_body')) changed = true;
    }
    if (!_whoopLinked) {
      const whoopKeys = [
        'whoop_sleep',
        'whoop_recovery',
        'whoop_cycle',
        'whoop_body',
      ];
      for (final key in whoopKeys) {
        if (_statOrder.remove(key)) {
          changed = true;
        }
      }
    }
    if (changed) {
      _saveStatOrder();
      if (mounted) setState(() {});
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
    }

    if (!_statOrder.contains(key)) {
      setState(() => _statOrder.add(key));
      _saveStatOrder();
    }

    if (key.startsWith('whoop_')) {
      _loadWhoopRecovery();
    }
    if (key == 'fitbit_activity') {
      _loadFitbitSummary();
    }
    if (key == 'fitbit_heart') {
      _loadFitbitSummary();
    }
    if (key == 'fitbit_sleep') {
      _loadFitbitSummary();
    }
    if (key == 'fitbit_vitals') {
      _loadFitbitSummary();
    }
    if (key == 'fitbit_body') {
      _loadFitbitSummary();
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
          child: Transform.rotate(
            angle: angle,
            child: child,
          ),
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
    return Opacity(
      opacity: isDragging ? 0.0 : 1.0,
      child: child,
    );
  }

  Widget _buildRemovableTile(String key, Widget child) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          ignoring: _wiggling,
          child: child,
        ),
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
                      border: Border.all(color: const Color(0xFFFF6B6B), width: 1.6),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.remove, color: Color(0xFFFF6B6B), size: 16),
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
        onPanStart: _wiggling ? (d) => _beginDrag(key, d.globalPosition, tile) : null,
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


  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUserInfo(),
      _loadNews(),
      _loadGoals(),
      _loadSteps(),
      _loadSleep(),
      _loadCalories(),
      _loadWater(),
      _loadWeeklySteps(),
      _loadTrendSleep(),
      _loadTrendCalories(),
      _loadWhoopRecovery(),
    ]);
    if (!mounted) return;
    await _loadFitbitStatus();
    _loadFitbitSummary();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
    });
    DailyMetricsApi.clearCache();
    await Future.wait([
      _loadUserInfo(),
      _loadNews(),
      _loadSteps(),
      _loadSleep(),
      _loadCalories(),
      _loadWater(),
      _loadWeeklySteps(),
      _loadTrendSleep(),
      _loadTrendCalories(),
      _loadExerciseProgress(),
      _loadWhoopRecovery(),
    ]);
    await _loadFitbitStatus();
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
    try {
      final statusUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/status?user_id=$userId");
      final headers = await AccountStorage.getAuthHeaders();
      final statusRes =
          await http.get(statusUrl, headers: headers).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (statusRes.statusCode != 200) {
        setState(() => _fitbitLinked = false);
        _pruneDeviceWidgets();
        return;
      }
      final statusData = jsonDecode(statusRes.body) as Map<String, dynamic>;
      final linked = statusData["linked"] == true;
      if (!mounted) return;
      setState(() => _fitbitLinked = linked);
      _pruneDeviceWidgets();
    } catch (_) {
      if (!mounted) return;
      setState(() => _fitbitLinked = false);
      _pruneDeviceWidgets();
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
    final anchor = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return _complianceCompletedForWeek(compliance, weekStart, weekEnd);
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
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
    return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
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
            compliance['updated_at'] ??
            compliance['performed_at'],
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
      ex['updated_at'],
      ex['performed_at'],
      ex['last_performed_at'],
    ];
    for (final c in candidates) {
      final dt = _parseDateTime(c);
      if (dt != null) return dt;
    }
    return null;
  }

  bool _isExerciseCompletedForWeek(
    Map<String, dynamic> ex,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (_complianceCompletedForWeek(ex['program_compliance'], weekStart, weekEnd) ||
        _complianceCompletedForWeek(ex['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final completionDate = _exerciseCompletionDate(ex);
    if (completionDate != null && !_isInWeek(completionDate, weekStart, weekEnd)) {
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

  DateTime? _parseDayDate(dynamic day) {
    if (day is Map) {
      for (final key in ['date', 'day_date', 'scheduled_date', 'training_date', 'day']) {
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

  Future<void> _loadExerciseProgress({bool force = false}) async {
    if (!force && _exerciseLoading) return;
    setState(() => _exerciseLoading = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        setState(() {
          _exerciseTotal = 0;
          _exerciseCompleted = 0;
        });
        return;
      }

      final anchor = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final progress = await TrainingService.fetchTrainingProgress(
        userId: userId,
        start: weekStart,
        end: weekEnd,
      );
      final total = (progress["total"] ?? 0) as int;
      final done = (progress["completed"] ?? 0) as int;
      final mode = progress["program_mode"] as String?;
      debugPrint(
        "Training progress db: user=$userId start=${weekStart.toIso8601String().split('T').first} "
        "end=${weekEnd.toIso8601String().split('T').first} completed=$done total=$total",
      );

      if (!mounted) return;
      setState(() {
        _exerciseTotal = total;
        _exerciseCompleted = done;
        _exerciseLoadedOnce = true;
        _exerciseProgramMode = mode;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exerciseTotal = null;
        _exerciseCompleted = null;
        _exerciseLoadedOnce = true;
      });
    } finally {
      if (mounted) {
        setState(() => _exerciseLoading = false);
      }
    }
  }

  Future<void> refreshExerciseProgress() => _loadExerciseProgress();

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
          final entry = await DailyMetricsApi.fetchForDate(userId, _selectedDate);
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
          final entry = await DailyMetricsApi.fetchForDate(userId, _selectedDate);
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
      int? kcal;
      if (_isToday()) {
        kcal = await CaloriesService().fetchTodayCalories();
      } else {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          final entry = await DailyMetricsApi.fetchForDate(userId, _selectedDate);
          kcal = entry?.calories;
          if (kcal == null) {
            kcal = await CaloriesService().fetchCaloriesForDay(_selectedDate);
          }
        }
      }
      if (!mounted) return;
      int? delta;
      if (kcal != null) {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          try {
            final yesterday = _selectedDate.subtract(const Duration(days: 1));
            final entry = await DailyMetricsApi.fetchForDate(userId, yesterday);
            final yCal = entry?.calories;
            if (yCal != null) {
              delta = kcal - yCal;
            }
          } catch (_) {}
        }
      }
      setState(() {
        _todayCalories = kcal;
        _caloriesDelta = delta;
      });
      // Submit burn for this date whenever we have a value (no run limit). When user
      // lowers calories burned, backend reduces surplus and targets for that date.
      if (kcal != null) {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          try {
            await DailyMetricsApi.submitBurn(
              userId: userId,
              caloriesBurned: kcal,
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
          final entry = await DailyMetricsApi.fetchForDate(userId, _selectedDate);
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
      scoreNode is Map<String, dynamic> ? scoreNode["sleep_score_percent"] : null,
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

  Future<void> _loadWhoopRecovery() async {
    final int requestId = ++_whoopReqId;
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    final bool isCurrentDay = _isToday();
    if (userId == null || userId == 0) {
      if (requestId != _whoopReqId) return;
          setState(() {
            _whoopLinked = false;
            _whoopLinkedKnown = true;
            _whoopRecovery = null;
            _whoopSleepHours = null;
            _whoopSleepScore = null;
            _whoopLoading = false;
            _whoopBodyWeightKg = null;
          });
          return;
    }

    // Preserve last known strain before refresh so UI doesn't drop to "—".
    if (_whoopCycleStrain != null) {
      _whoopCycleStrainLast = _whoopCycleStrain;
    }
    setState(() => _whoopLoading = true);
    try {
      if (!_useWhoop && !_hasAnyWhoopWidget) {
        if (!mounted) return;
        if (requestId != _whoopReqId) return;
        setState(() {
          _whoopLinked = true;
          _whoopRecovery = null;
          _whoopSleepHours = null;
          _whoopSleepScore = null;
          _whoopLoading = false;
          _whoopBodyWeightKg = null;
        });
        return;
      }

      final snapshot = await WhoopWidgetDataService().fetchForDate(_selectedDate);
      if (requestId != _whoopReqId) return;

      if (!mounted) return;
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopLinked = snapshot.linked;
        _whoopLinkedKnown = snapshot.linkedKnown;
        _whoopRecovery = snapshot.recoveryScore;
        _whoopSleepHours = snapshot.sleepHours;
        _whoopSleepScore = snapshot.sleepScore;
        _whoopSleepDelta = snapshot.sleepDelta;
        _whoopRecoveryDelta = snapshot.recoveryDelta;
        _whoopLoading = false;
        _whoopCycleStrain = snapshot.cycleStrain;
        _whoopBodyWeightKg = snapshot.bodyWeightKg;
        if (snapshot.cycleStrain != null && isCurrentDay) {
          _whoopCycleStrainLast = snapshot.cycleStrain;
        }
      });
      _pruneDeviceWidgets();
      if (!_trendSleepLoading) {
        _loadTrendSleep();
      }
    } catch (_) {
      if (!mounted) return;
      if (requestId != _whoopReqId) return;
      setState(() {
        _whoopRecovery = null;
        _whoopSleepHours = null;
        _whoopSleepScore = null;
        _whoopLoading = false;
      });
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

  Future<void> _loadFitbitSummary({int attempt = 0}) async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isToday = selectedDay == todayOnly;
    if (userId == null || userId == 0) {
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 400 + (attempt * 400)));
        if (!mounted) return;
        return _loadFitbitSummary(attempt: attempt + 1);
      }
      if (!mounted) return;
      setState(() {
        _fitbitLinked = false;
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
      });
      return;
    }

    await _loadFitbitStatus();
    if (!_fitbitLinked) return;

    // Always load Fitbit summaries when linked, even if widgets are currently hidden.

    setState(() {
      _fitbitActivityLoading = true;
      _fitbitHeartLoading = true;
      _fitbitSleepLoading = true;
      _fitbitVitalsLoading = true;
      _fitbitBodyLoading = true;
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
          _fitbitActivityLoading = false;
          _fitbitHeartLoading = false;
          _fitbitSleepLoading = false;
          _fitbitVitalsLoading = false;
          _fitbitBodyLoading = false;
        });
        return;
      }

      final bundle = await FitbitSummaryService().fetchSummary(
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      );
      if (!mounted) return;
      setState(() {
        _fitbitActivity = bundle?.activity;
        _fitbitActivityLast = isToday ? (bundle?.activity ?? _fitbitActivityLast) : null;
        _fitbitHeart = bundle?.heart;
        _fitbitHeartLast = isToday ? (bundle?.heart ?? _fitbitHeartLast) : null;
        _fitbitSleep = bundle?.sleep;
        _fitbitSleepLast = isToday ? (bundle?.sleep ?? _fitbitSleepLast) : null;
        _fitbitVitals = bundle?.vitals;
        _fitbitVitalsLast = isToday ? (bundle?.vitals ?? _fitbitVitalsLast) : null;
        _fitbitBody = bundle?.body;
        _fitbitBodyLast = isToday ? (bundle?.body ?? _fitbitBodyLast) : null;
        _fitbitActivityLoading = false;
        _fitbitHeartLoading = false;
        _fitbitSleepLoading = false;
        _fitbitVitalsLoading = false;
        _fitbitBodyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fitbitActivityLoading = false;
        _fitbitHeartLoading = false;
        _fitbitSleepLoading = false;
        _fitbitVitalsLoading = false;
        _fitbitBodyLoading = false;
      });
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
    final map = <DateTime, DailyMetricsEntry?>{};
    for (final d in days) {
      final entry = fetched[d];
      if (entry != null) {
        map[d] = entry;
      } else {
        // Fallback: pull local data for that specific day if the backend has nothing.
        final steps = await StepsService().fetchStepsForDay(d);
        final sleep = await SleepService().fetchSleepForDay(d);
        final calories = await CaloriesService().fetchCaloriesForDay(d);
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
      final localCalories = await CaloriesService().fetchTodayCalories();
      final localWater = await WaterService().getIntakeForDay(todayKey);
      map[todayKey] = DailyMetricsEntry(
        entryDate: todayKey,
        steps: current?.steps ?? localSteps,
        sleepHours: current?.sleepHours ?? localSleep,
        calories: current?.calories ?? localCalories,
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
      final anchor = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
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
        total = metrics.values.fold<int>(0, (sum, entry) => sum + (entry?.steps ?? 0));
      } else {
        final data = await StepsService().fetchDailySteps(start: monday, end: end);
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

  Future<void> _loadTrendSleep() async {
    setState(() => _trendSleepLoading = true);
    try {
      final anchor = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final start = anchor.subtract(const Duration(days: 6));
      List<double> days;
      if (_hasWhoopSleepWidget && _whoopLinked) {
        final data = await WhoopSleepService().fetchDailySleep(start: start, end: anchor);
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        final anchorKey = DateTime(anchor.year, anchor.month, anchor.day);
        if (anchorKey == todayKey) {
          try {
            final latest = await WhoopSleepService().fetchLatestSleepDaily();
            if (latest.isNotEmpty) {
              for (final entry in latest.entries) {
                final key = DateTime(entry.key.year, entry.key.month, entry.key.day);
                if (key.isBefore(start) || key.isAfter(anchor)) continue;
                if (!data.containsKey(key)) {
                  data[key] = entry.value;
                }
              }
            }
          } catch (_) {
            // ignore latest fetch errors
          }
        }
        days = List.generate(7, (i) {
          final d = DateTime(anchor.year, anchor.month, anchor.day)
              .subtract(Duration(days: 6 - i));
          final key = DateTime(d.year, d.month, d.day);
          return data[key] ?? 0.0;
        });
      } else {
        final metrics = await _fetchMetricsRange(start, anchor);
        if (metrics.isNotEmpty) {
          days = List.generate(7, (i) {
            final d = DateTime(anchor.year, anchor.month, anchor.day)
                .subtract(Duration(days: 6 - i));
            final key = DateTime(d.year, d.month, d.day);
            final entry = metrics[key];
            return (entry?.sleepHours ?? 0.0).toDouble();
          });
        } else {
          final data = await SleepService().fetchDailySleep(start: start, end: anchor);
          days = List.generate(7, (i) {
            final d = DateTime(anchor.year, anchor.month, anchor.day)
                .subtract(Duration(days: 6 - i));
            final key = DateTime(d.year, d.month, d.day);
            return data[key] ?? 0.0;
          });
        }
      }
      final hasData = days.any((v) => v > 0);
      if (!mounted) return;
      setState(() => _trendSleep = hasData ? days : const []);
    } catch (_) {
      if (!mounted) return;
      setState(() => _trendSleep = const []);
    } finally {
      if (mounted) setState(() => _trendSleepLoading = false);
    }
  }

  Future<void> _loadTrendCalories() async {
    setState(() => _trendCaloriesLoading = true);
    try {
      final anchor = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final start = anchor.subtract(const Duration(days: 6));
      final metrics = await _fetchMetricsRange(start, anchor);
      List<double> days;
      if (metrics.isNotEmpty) {
        days = List.generate(7, (i) {
          final d = DateTime(anchor.year, anchor.month, anchor.day)
              .subtract(Duration(days: 6 - i));
          final key = DateTime(d.year, d.month, d.day);
          final entry = metrics[key];
          return (entry?.calories ?? 0).toDouble();
        });
      } else {
        final data =
            await CaloriesService().fetchDailyCalories(start: start, end: anchor);
        days = List.generate(7, (i) {
          final d = DateTime(anchor.year, anchor.month, anchor.day)
              .subtract(Duration(days: 6 - i));
          final key = DateTime(d.year, d.month, d.day);
          return (data[key] ?? 0).toDouble();
        });
      }
      final hasData = days.any((v) => v > 0);
      if (!mounted) return;
      setState(() => _trendCalories = hasData ? days : const []);
    } catch (_) {
      if (!mounted) return;
      setState(() => _trendCalories = const []);
    } finally {
      if (mounted) setState(() => _trendCaloriesLoading = false);
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
        final fullName = profile["full_name"]?.toString();
        final remoteAvatar = profile["avatar_url"]?.toString();
        final height = profile["height_cm"];
        final weight = profile["weight_kg"];
        if (fullName != null && fullName.trim().isNotEmpty) {
          fetchedName = fullName;
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

  Future<void> _loadBodyMeasurements() async {
    final userId = await AccountStorage.getUserId();
    final key = userId == null ? "body_measurements" : "body_measurements_u$userId";
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnnouncementsPage(items: _news)),
    );
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
          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
        );
      }
    }

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
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

    final averageSleep = _sleepHours ??
        (_mockSleepHours.isEmpty
            ? 0
            : _mockSleepHours.reduce((a, b) => a + b) / _mockSleepHours.length);
    final weeklySteps = _weeklySteps ?? (_mockSteps.isEmpty ? 0 : _mockSteps.reduce((a, b) => a + b));
    final todaysStepsDisplay = _todaySteps ?? 0;
    final todaysCaloriesDisplay = _todayCalories ?? 0;
    final waterGoal = _waterGoal ?? 2.5;
    final waterIntake = _waterIntake ?? 0;
    final weeklyStepGoalTotal = (_stepsGoal ?? 10000) * 7;
    final weeklyProgress = weeklyStepGoalTotal == 0
        ? 0.0
        : (weeklySteps / weeklyStepGoalTotal).clamp(0.0, 2.0);
    final metricsLoading = _stepsLoading || _sleepLoading || _caloriesLoading || _waterLoading;
    final noEntriesForSelectedDate = !_isToday() &&
        !metricsLoading &&
        _todaySteps == null &&
        _sleepHours == null &&
        _todayCalories == null &&
        _waterIntake == null;
    final todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final selectedDayOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isYesterday = selectedDayOnly == todayOnly.subtract(const Duration(days: 1));
    final relativeDateLabel = _isToday()
        ? t("date_today")
        : isYesterday
            ? t("date_yesterday")
            : DateFormat('MMM d, y', locale).format(_selectedDate);
    final bool isCurrentDay = _isToday();

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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
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
                ],
              ),
            ),
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (_avatarUrl == null || _avatarUrl!.isEmpty) &&
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
              child: ClipOval(
                child: _buildAvatar(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const CardContainer(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (noEntriesForSelectedDate)
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
                  Text(t("dash_news_tag"),
                      style: const TextStyle(color: Colors.white)),
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
        CardContainer(
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
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.accent),
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
                                        color: Colors.white70, fontSize: 12),
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
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _exerciseTotal == null
                            ? t("dash_exercise_unavailable")
                            : _exerciseProgramMode == "old"
                                ? "${(_exerciseCompleted ?? 0).toString()} / ${_exerciseTotal.toString()} old program days"
                                : "${(_exerciseCompleted ?? 0).toString()} / ${_exerciseTotal.toString()} days done",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      if (_exerciseProgramMode == "old")
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            "Old program",
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_loading && !noEntriesForSelectedDate) ...[
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              Widget buildTileForKey(String key) {
                switch (key) {
                  case 'steps':
                    return StatCard(
                      title: t("dash_today_steps"),
                      value:
                          (_stepsLoading && _todaySteps == null)
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
                      loading: _whoopLoading,
                      linked: _whoopLinked,
                      linkedKnown: _whoopLinkedKnown,
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
                      loading: _whoopLoading,
                      linked: _whoopLinked,
                      score: _whoopRecovery,
                      delta: _whoopRecoveryDelta,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WhoopRecoveryDetailPage(),
                          ),
                        );
                      },
                    );
                  case 'whoop_cycle':
                    final strain = isCurrentDay
                        ? (_whoopCycleStrain ?? _whoopCycleStrainLast)
                        : _whoopCycleStrain;
                    return WhoopCycleCard(
                      loading: _whoopLoading,
                      linked: _whoopLinked,
                      strain: strain,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WhoopCycleDetailPage(),
                          ),
                        );
                      },
                    );
                  case 'whoop_body':
                    return WhoopBodyCard(
                      loading: _whoopLoading,
                      linked: _whoopLinked,
                      weightKg: _whoopBodyWeightKg,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WhoopBodyDetailPage(),
                          ),
                        );
                      },
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
                      onTap: () async {
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
                      },
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
                      onTap: summary == null
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
                      onTap: () async {
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
                      },
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
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => FitbitSleepSheet(
                            summary: sleep,
                            date: _selectedDate,
                          ),
                        );
                      },
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
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => FitbitVitalsSheet(summary: vitals),
                        );
                      },
                    );
                  case 'fitbit_body':
                    final body = _fitbitBodyLoading
                        ? (_fitbitBodyLast ?? _fitbitBody)
                        : _fitbitBody;
                    final loading = _fitbitBodyLoading && body == null;
                    return FitbitBodyCard(
                      loading: loading,
                      weightKg: body?.weightKg,
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => FitbitBodySheet(summary: body),
                        );
                      },
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
          if (_whoopLinked) ...[
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
                            cycleStrain:
                                _whoopCycleStrainLast ?? _whoopCycleStrain,
                            hideSleep: _statOrder.contains('whoop_sleep'),
                            hideRecovery:
                                _statOrder.contains('whoop_recovery'),
                            hideCycle: _statOrder.contains('whoop_cycle'),
                            hideBody: _statOrder.contains('whoop_body'),
                          ),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 16),
          ],
          if (_fitbitLinked) ...[
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
                              hideActivity:
                                  _statOrder.contains('fitbit_activity'),
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
            onTap: _wiggling ? null : _loadWeeklySteps,
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
                        data: _trendSleep,
                        loading: _trendSleepLoading,
                        accentColor: const Color(0xFF9B8CFF),
                        emptyLabel: t("dash_no_sleep_data"),
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
          _PlaceholderMetricCard(
            title: t("dash_taqa_score"),
            subtitle: t("dash_placeholder"),
            icon: Icons.bolt,
            accentColor: const Color(0xFF6A5AE0),
          ),
          const SizedBox(height: 60),
        ],
      ],
    );
  

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        notificationPredicate: (_) => isCurrentDay,
        onRefresh: (!_wiggling && isCurrentDay) ? _refreshAll : () async {},
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                              const Icon(Icons.calendar_today,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCurrentDay
                                        ? t("date_today")
                                        : DateFormat('EEE', locale)
                                            .format(_selectedDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, y', locale)
                                        .format(_selectedDate),
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
                  colors: [
                    accentColor,
                    accentColor.withOpacity(0.65),
                  ],
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
    );
  }
}

class _TrendTile extends StatelessWidget {
  final String title;
  final List<double> data;
  final bool loading;
  final Color accentColor;
  final String emptyLabel;

  const _TrendTile({
    required this.title,
    required this.data,
    required this.loading,
    required this.accentColor,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (data.isEmpty) {
      return Text(
        emptyLabel,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.white60),
      );
    }
    return BarTrend(
      title: title,
      data: data,
      accentColor: accentColor,
    );
  }
}
