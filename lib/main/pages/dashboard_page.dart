import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';
import '../../widgets/news_carousel.dart';
import '../../screens/announcements_page.dart';
import '../../services/news_service.dart';
import '../../models/news_item.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/dashboard/progress_meter.dart';
import '../../widgets/dashboard/bar_trend.dart';
import '../../theme/app_theme.dart';
import '../../core/account_storage.dart';
import '../../services/profile_service.dart';
import '../../services/daily_metrics_api.dart';
import '../../config/base_url.dart';
import '../../services/steps_service.dart';
import '../../services/sleep_service.dart';
import '../../services/calories_service.dart';
import '../../services/water_service.dart';
import '../../screens/sleep_detail_page.dart';
import '../../screens/steps_detail_page.dart';
import '../../screens/calories_detail_page.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common/date_header.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<NewsItem> _news = const [];
  bool _loading = true;
  String? _error;
  final _mockSteps = [8200, 9100, 10400, 7600, 8800, 9900, 11200];
  final _mockSleepHours = [6.5, 7.0, 7.2, 6.8, 7.5, 7.8, 8.0];
  String? _avatarUrl;
  String? _avatarPath;
  String? _displayName;
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
  int? _weeklySteps;
  bool _weeklyStepsLoading = false;
  List<double> _trendSleep = const [];
  List<double> _trendCalories = const [];
  bool _trendSleepLoading = false;
  bool _trendCaloriesLoading = false;
  DateTime _selectedDate = DateTime.now();
  int _weeklyDaysCount = 7;

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
    setState(() => _selectedDate = next);
    _loadSteps();
    _loadSleep();
    _loadCalories();
    _loadWater();
    _loadWeeklySteps();
    _loadTrendSleep();
    _loadTrendCalories();
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
    _loadUserInfo();
    _loadNews();
    _loadGoals();
    _loadSteps();
    _loadSleep();
    _loadCalories();
    _loadWater();
    _loadWeeklySteps();
    _loadTrendSleep();
    _loadTrendCalories();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
    });
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
    ]);
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
          final entry = await DailyMetricsApi.fetchForDate(userId, _selectedDate);
          steps = entry?.steps;
          if (steps == null) {
            steps = await StepsService().fetchStepsForDay(_selectedDate);
          }
        }
      }
      if (!mounted) return;
      setState(() => _todaySteps = steps);
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
      setState(() => _sleepHours = hours);
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
      setState(() => _todayCalories = kcal);
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
      setState(() {
        _waterGoal = goal;
        _waterIntake = intake;
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

  Future<void> _openWaterEditor() async {
    final t = AppLocalizations.of(context).translate;
    final goalController = TextEditingController(
      text: (_waterGoal ?? 2.5).toStringAsFixed(1),
    );
    final intakeController = TextEditingController(
      text: (_waterIntake ?? 0).toStringAsFixed(1),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: Text(t("water_title"), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: goalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t("water_goal_label"),
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: t("water_goal_hint"),
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: intakeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: t("water_intake_label"),
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: t("water_intake_hint"),
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t("common_cancel")),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t("common_save")),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final goal = double.tryParse(goalController.text.trim());
      final intake = double.tryParse(intakeController.text.trim());
      final service = WaterService();
      if (goal != null && goal > 0) {
        await service.setGoal(goal);
      }
      if (intake != null && intake >= 0) {
        await service.setTodayIntake(intake);
      }
      if (mounted) {
        _loadWater();
      }
    }
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
    final map = <DateTime, DailyMetricsEntry?>{};
    for (final d in days) {
      final entry = await DailyMetricsApi.fetchForDate(userId, d);
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
      final metrics = await _fetchMetricsRange(start, anchor);
      List<double> days;
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
    final storedAvatar = await AccountStorage.getAvatarUrl();
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

    if (userId != null) {
      try {
        final profile = await ProfileApi.fetchProfile(userId);
        final fullName = profile["full_name"]?.toString();
        final remoteAvatar = profile["avatar_url"]?.toString();
        if (fullName != null && fullName.trim().isNotEmpty) {
          fetchedName = fullName;
        }
        if (remoteAvatar != null && remoteAvatar.trim().isNotEmpty) {
          fetchedAvatar = remoteAvatar;
        }
      } catch (_) {
        // Ignore and fallback to stored values
      }
    }

    if (!mounted) return;
    setState(() {
      _avatarUrl = fetchedAvatar;
      _avatarPath = storedAvatarPath;
      _displayName = fetchedName;
    });
  }

  Future<void> _loadNews() async {
    try {
      final items = await NewsApi.fetchNews(limit: 10);
      if (!mounted) return;
      setState(() {
        _news = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
          cacheWidth: 128,
          cacheHeight: 128,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
        );
      }
    }

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return Image.network(
        _fullUrl(_avatarUrl!),
        cacheWidth: 128,
        cacheHeight: 128,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
      );
    }

    return const Center(child: Icon(Icons.person, color: Colors.white));
  }

  String _fullUrl(String path) {
    if (path.startsWith("http")) return path;
    return "${ApiConfig.baseUrl}$path";
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

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: _refreshAll,
        child: Stack(
          children: [
            ListView(
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
                  if (_todaySteps == null &&
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
                          Text(t("dash_news_tag"), style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    NewsCarousel(slides: slides),
                ],
                const SizedBox(height: 16),
    if (!_loading && !noEntriesForSelectedDate) ...[
      const SizedBox(height: 20),
      GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.10,
        children: [
                      StatCard(
                        title: t("dash_today_steps"),
                        value: _stepsLoading ? "…" : "${todaysStepsDisplay.toString()}",
                        subtitle: "${t("dash_goal")} ${(_stepsGoal ?? 10000).toString()}",
                        icon: Icons.directions_walk,
                        accentColor: const Color(0xFF35B6FF),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StepsDetailPage()),
                          );
                          await _loadGoals();
                          await _loadSteps();
                        },
                        onLongPress: _editStepsGoal,
                      ),
                      StatCard(
                        title: t("dash_today_sleep"),
                        value: _sleepLoading
                            ? "…"
                            : "${averageSleep.toStringAsFixed(1)} ${t("dash_unit_hrs")}",
                        subtitle: "${t("dash_goal")} ${(_sleepGoal ?? 8.0).toStringAsFixed(1)} ${t("dash_unit_hrs")}",
                        icon: Icons.nights_stay,
                        accentColor: const Color(0xFF9B8CFF),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SleepDetailPage()),
                          );
                          await _loadGoals();
                          await _loadSleep();
                        },
                        onLongPress: _editSleepGoal,
                      ),
                      StatCard(
                        title: t("dash_water_intake"),
                        value: _waterLoading ? "…" : "${waterIntake.toStringAsFixed(1)} ${t("dash_unit_l")}",
            subtitle: _waterLoading ? "" : "${t("dash_goal")} ${waterGoal.toStringAsFixed(1)} ${t("dash_unit_l")}",
            icon: Icons.water_drop,
            accentColor: const Color(0xFF00BFA6),
            onTap: _isToday() ? _openWaterEditor : null,
            onLongPress: _isToday() ? _openWaterEditor : null,
          ),
                      StatCard(
                        title: t("dash_calories_burned"),
                        value: _caloriesLoading
                            ? "…"
                            : "${todaysCaloriesDisplay.toString()} ${t("dash_unit_kcal")}",
                        subtitle: "${t("dash_goal")} ${(_caloriesGoal ?? 500).toString()}",
                        icon: Icons.local_fire_department,
                        accentColor: const Color(0xFFFF8A00),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CaloriesDetailPage()),
                          );
                          await _loadGoals();
                          await _loadCalories();
                        },
                        onLongPress: _editCaloriesGoal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ProgressMeter(
                    title: t("dash_weekly_goal"),
                    progress: weeklyProgress,
                    targetLabel: "${t("dash_target")}: $weeklyStepGoalTotal ${t("dash_steps_week")}",
                    trailingLabel: _weeklyStepsLoading ? t("dash_loading") : "$weeklySteps ${t("dash_steps_label")}",
                    accentColor: const Color(0xFF35B6FF),
                    onTap: _loadWeeklySteps,
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
                ],
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20 + bottomInset,
              child: GestureDetector(
                onTap: _openDateSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
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
                      const Icon(Icons.calendar_month, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            relativeDateLabel,
                            style: AppTextStyles.small.copyWith(color: Colors.white70),
                          ),
                          Text(
                            DateFormat('dd/MM', locale).format(_selectedDate),
                            style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.expand_more, color: Colors.white70, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
