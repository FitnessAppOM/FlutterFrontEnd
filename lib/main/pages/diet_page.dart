import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/diet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/diet_item_search_sheet.dart';
import '../../widgets/diet_logging_options_sheet.dart';
import '../../widgets/diet_manual_entry_sheet.dart';
import '../../widgets/diet_photo_entry_sheet.dart';
import '../../services/training_completion_storage.dart';
import '../../services/training_calendar_service.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => DietPageState();
}

class DietPageState extends State<DietPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _targets;
  bool _targetsFromCache = false;

  bool _mealsLoading = true;
  String? _mealsError;
  Map<String, dynamic>? _meals;
  final DateTime _mealDate = DateTime.now();
  bool _mealsFromCache = false;
  bool _freezing = false;

  int _modeIndex = 0; // 0 = Rest, 1 = Training
  int _selectedTrainingDayIndex = 0;
  /// When true, user completed an exercise today so we force "training day" and disable switching to "rest day".
  bool _trainDayLockedByExercise = false;

  static bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _loadTargets();
    _loadMeals();
    _updateTrainingLockFromCompletion();
  }

  /// Call when user switches to diet tab (e.g. after finishing a workout) so we refresh lock state.
  Future<void> refreshTrainingLock() async {
    await _updateTrainingLockFromCompletion();
  }

  Future<void> _updateTrainingLockFromCompletion() async {
    final viewingToday = _sameCalendarDay(_mealDate, DateTime.now());
    if (!viewingToday) {
      if (mounted) setState(() => _trainDayLockedByExercise = false);
      return;
    }
    final didComplete = await TrainingCompletionStorage.didCompleteExerciseOnDate(_mealDate);
    if (!mounted) return;
    setState(() {
      _trainDayLockedByExercise = didComplete;
      if (didComplete) _modeIndex = 1;
    });
    if (didComplete) _loadMeals();
  }

  Future<void> _loadTargets({bool forceNetwork = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      _targetsFromCache = false;
    });

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        throw Exception("User not found");
      }

      final data = await DietService.fetchCurrentTargets(userId);
      if (!mounted) return;
      setState(() {
        _targets = data;
        _loading = false;
        _error = null;
        _targetsFromCache = false;
        _selectedTrainingDayIndex = 0;
      });
    } catch (e) {
      // Cache fallback (offline-friendly)
      try {
        final cached = await DietService.fetchCurrentTargetsFromCache();
        if (!mounted) return;
        if (cached != null) {
          setState(() {
            _targets = cached;
            _loading = false;
            _targetsFromCache = true;
            _selectedTrainingDayIndex = 0;
          });
          return;
        }
      } catch (_) {
        // ignore cache load errors
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _targetsFromCache = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? "") ?? fallback;
  }

  static String _asString(dynamic v) => (v == null ? "" : v.toString()).trim();

  static String _dateLabel(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  Future<void> _loadMeals() async {
    setState(() {
      _mealsLoading = true;
      _mealsError = null;
      _mealsFromCache = false;
    });

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        throw Exception("User not found");
      }

      // auto_open=true will create Meal 1..N if missing
      final data = await DietService.fetchMealsForDate(
        userId,
        date: _mealDate,
        autoOpen: true,
      );
      if (!mounted) return;

      // If day_summary isn't in response, fetch it separately
      if (data["day_summary"] == null) {
        try {
          final summary = await DietService.fetchDaySummary(
            userId,
            date: _mealDate,
          );
          data["day_summary"] = summary;
        } catch (_) {
          // Ignore if summary fetch fails
        }
      }

      setState(() {
        _meals = data;
        _mealsLoading = false;
        _mealsError = null;
        _mealsFromCache = false;
      });
    } catch (e) {
      // Cache fallback (offline-friendly)
      try {
        final cached = await DietService.fetchMealsForDateFromCache(
          _mealDate,
        );
        if (!mounted) return;
        if (cached != null) {
          setState(() {
            _meals = cached;
            _mealsLoading = false;
            _mealsFromCache = true;
          });
          return;
        }
      } catch (_) {
        // ignore cache load errors
      }

      if (!mounted) return;
      setState(() {
        _mealsLoading = false;
        _mealsFromCache = false;
        _mealsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _trainingDays {
    final list = _targets?["training_day_targets"];
    if (list is List) {
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  Map<String, dynamic>? get _selectedTrainingDay {
    final days = _trainingDays;
    if (days.isEmpty) return null;
    final idx = _selectedTrainingDayIndex.clamp(0, days.length - 1);
    return days[idx];
  }

  Widget _macroChip({
    required String label,
    required int grams,
    required Color color,
    required IconData icon,
    String unit = "g",
    int? target,
    int? remaining,
  }) {
    final hasTarget = target != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            hasTarget ? "$label $grams / $target$unit" : "$label $grams$unit",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _mealList {
    final list = _meals?["meals"];
    if (list is List) {
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  Map<String, dynamic>? get _daySummary {
    final ds = _meals?["day_summary"];
    if (ds is Map) return ds.cast<String, dynamic>();
    return null;
  }

  Map<String, dynamic>? get _daySummaryLive {
    // Backend returns day_summary with target/consumed/remaining directly
    // Check if there's a "live" wrapper, otherwise use day_summary directly
    final live = _daySummary?["live"];
    if (live is Map) return live.cast<String, dynamic>();
    // If no "live" wrapper, the day_summary itself contains target/consumed/remaining
    if (_daySummary != null && (_daySummary!["target"] != null || _daySummary!["remaining"] != null)) {
      return _daySummary;
    }
    return null;
  }

  Map<String, dynamic>? get _daySummarySnapshot {
    final snap = _daySummary?["snapshot"];
    if (snap is Map) return snap.cast<String, dynamic>();
    return null;
  }

  int _dsInt(Map<String, dynamic>? m, String key) => _asInt(m?[key], fallback: 0);

  Future<void> _freezeDay() async {
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    setState(() => _freezing = true);
    try {
      await DietService.captureDaySummary(
        userId,
        date: _mealDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_day_frozen"))),
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("diet_freeze_failed")}: $e")),
      );
    } finally {
      if (mounted) setState(() => _freezing = false);
    }
  }

  Map<String, int> _sumMealItemsMacros(Map<String, dynamic> meal) {
    final items = meal["items"];
    if (items is! List) {
      return const {"calories": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0};
    }

    var cal = 0;
    var p = 0;
    var c = 0;
    var f = 0;

    for (final it in items) {
      if (it is! Map) continue;
      cal += _asInt(it["calories"]);
      p += _asInt(it["protein_g"]);
      c += _asInt(it["carbs_g"]);
      f += _asInt(it["fat_g"]);
    }

    return {"calories": cal, "protein_g": p, "carbs_g": c, "fat_g": f};
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final restCalories = _asInt(_targets?["rest_calories"]);
    final restP = _asInt(_targets?["rest_protein_g"]);
    final restC = _asInt(_targets?["rest_carbs_g"]);
    final restF = _asInt(_targets?["rest_fat_g"]);

    final td = _selectedTrainingDay;
    final trainCalories = _asInt(td?["train_calories"]);
    final trainP = _asInt(td?["train_protein_g"]);
    final trainC = _asInt(td?["train_carbs_g"]);
    final trainF = _asInt(td?["train_fat_g"]);

    final activeCalories = _modeIndex == 0 ? restCalories : trainCalories;
    final activeP = _modeIndex == 0 ? restP : trainP;
    final activeC = _modeIndex == 0 ? restC : trainC;
    final activeF = _modeIndex == 0 ? restF : trainF;

    final createdBy = _asString(_targets?["created_by"]);
    final updatedAt = _asString(_targets?["updated_at"]);

    // Get consumption data from day_summary if available
    final live = _daySummaryLive;
    final target = (live?["target"] is Map) ? (live?["target"] as Map).cast<String, dynamic>() : null;
    final consumed = (live?["consumed"] is Map) ? (live?["consumed"] as Map).cast<String, dynamic>() : null;
    final remaining = (live?["remaining"] is Map) ? (live?["remaining"] as Map).cast<String, dynamic>() : null;
    
    final conCal = _dsInt(consumed, "calories");
    final tarCal = _dsInt(target, "calories");
    final remCal = _dsInt(remaining, "calories");
    final hasConsumption = conCal > 0 || tarCal > 0;
    final frozen = _daySummarySnapshot != null;

    final targetsSubtitle = _error ??
        (_targetsFromCache
            ? t.translate("diet_offline_targets")
            : t.translate("diet_targets_subtitle"));

    final mealsSubtitleSuffix = _mealsError ??
        (_mealsFromCache ? t.translate("diet_offline_meals") : "");
    final mealsSubtitle = mealsSubtitleSuffix.isEmpty
        ? _dateLabel(_mealDate)
        : "${_dateLabel(_mealDate)} • $mealsSubtitleSuffix";

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionHeader(title: t.translate("diet_title")),
          const SizedBox(height: 16),

          // --- Top: Targets (MyFitnessPal-like summary card) ---
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.restaurant_menu, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.translate("diet_daily_targets"),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            targetsSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasConsumption && !frozen)
                          IconButton(
                            tooltip: t.translate("diet_freeze_day"),
                            onPressed: _freezing ? null : _freezeDay,
                            icon: _freezing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.lock_outline, color: Colors.white70),
                          ),
                        IconButton(
                          tooltip: t.translate("diet_refresh"),
                          onPressed: _loading ? null : () => _loadTargets(forceNetwork: true),
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_loading) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: cs.primary),
                    ),
                  ),
                ] else if (_targets == null) ...[
                  Text(
                    t.translate("diet_no_targets_yet"),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _loadTargets(forceNetwork: true),
                      child: Text(t.translate("generating_retry")),
                    ),
                  ),
                ] else ...[
                  // Mode toggle (locked to Training when user completed an exercise today)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      return ToggleButtons(
                        isSelected: [_modeIndex == 0, _modeIndex == 1],
                        onPressed: (idx) async {
                          if (_trainDayLockedByExercise && idx == 0) return; // cannot switch to Rest when trained today
                          setState(() => _modeIndex = idx);
                          // Persist calendar mapping so backend can infer diet targets without training_day_id.
                          try {
                            final userId = await AccountStorage.getUserId();
                            if (userId != null) {
                              if (idx == 0) {
                                await TrainingCalendarService.setDay(
                                  userId: userId,
                                  entryDate: _mealDate,
                                  dayType: 'rest',
                                );
                              } else {
                                final tdId = _asInt(_selectedTrainingDay?["day_id"], fallback: 0);
                                await TrainingCalendarService.setDay(
                                  userId: userId,
                                  entryDate: _mealDate,
                                  dayType: 'training',
                                  trainingDayId: tdId > 0 ? tdId : 1,
                                );
                              }
                            }
                          } catch (_) {
                            // ignore calendar mapping errors; diet endpoints may still fall back
                          }
                          _loadMeals();
                        },
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white70,
                        selectedColor: Colors.black,
                        fillColor: Colors.white,
                        constraints: BoxConstraints(
                          minHeight: 42,
                          minWidth: (w - 6) / 2,
                        ),
                        children: [
                          Text(t.translate("diet_rest_day")),
                          Text(t.translate("diet_training_day")),
                        ],
                      );
                    },
                  ),

                  if (_modeIndex == 1) ...[
                    const SizedBox(height: 12),
                    _buildTrainingDayPicker(theme, onChanged: () => _loadMeals()),
                  ],

                  const SizedBox(height: 14),

                  // Calories headline - show consumed/target format if available
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                hasConsumption ? "$conCal" : "$activeCalories",
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              if (hasConsumption) ...[
                                Text(
                                  " / $tarCal",
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  t.translate("diet_kcal_unit"),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasConsumption && remCal != 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              remCal > 0 
                                  ? "${t.translate("diet_remaining")}: $remCal ${t.translate("diet_kcal_unit")}"
                                  : "${t.translate("diet_over")}: ${-remCal} ${t.translate("diet_kcal_unit")}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: remCal > 0 ? AppColors.successGreen : AppColors.errorRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      if (createdBy.isNotEmpty)
                        Text(
                          createdBy.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white54,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Macros chips - show consumed/target format if available
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _macroChip(
                        label: t.translate("protein"),
                        grams: hasConsumption && consumed != null
                            ? _dsInt(consumed, "protein_g")
                            : activeP,
                        target: hasConsumption && target != null ? _dsInt(target, "protein_g") : null,
                        color: AppColors.accent,
                        icon: Icons.fitness_center,
                      ),
                      _macroChip(
                        label: t.translate("diet_carbs"),
                        grams: hasConsumption && consumed != null
                            ? _dsInt(consumed, "carbs_g")
                            : activeC,
                        target: hasConsumption && target != null ? _dsInt(target, "carbs_g") : null,
                        color: AppColors.successGreen,
                        icon: Icons.bolt,
                      ),
                      _macroChip(
                        label: t.translate("diet_fat"),
                        grams: hasConsumption && consumed != null
                            ? _dsInt(consumed, "fat_g")
                            : activeF,
                        target: hasConsumption && target != null ? _dsInt(target, "fat_g") : null,
                        color: const Color(0xFFFFA726),
                        icon: Icons.opacity,
                      ),
                    ],
                  ),

                  if (updatedAt.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "${t.translate("diet_updated")}: $updatedAt",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Meals (auto-open per day) ---
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.today, color: AppColors.successGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.translate("diet_today_meals"),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mealsSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t.translate("diet_refresh_meals"),
                      onPressed: _mealsLoading ? null : _loadMeals,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_mealsLoading) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: CircularProgressIndicator(color: cs.primary),
                    ),
                  ),
                ] else if (_mealList.isEmpty) ...[
                  Text(
                    t.translate("diet_no_meals_today"),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final userId = await AccountStorage.getUserId();
                        if (userId == null) return;
                        await DietService.openMealsForDate(userId, date: _mealDate);
                        if (!mounted) return;
                        await _loadMeals();
                      },
                      child: Text(t.translate("diet_open_today_meals")),
                    ),
                  ),
                ] else ...[
                  ..._mealList.map((meal) {
                    final title = _asString(meal["title"]);
                    final idx = _asInt(meal["meal_index"], fallback: 0);
                    final items = meal["items"] is List ? (meal["items"] as List).length : 0;
                    final sums = _sumMealItemsMacros(meal);
                    final itemsLabel = items == 1
                        ? t.translate("diet_items_singular")
                        : t.translate("diet_items_plural");
                    final mealId = _asInt(meal["meal_id"], fallback: 0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title.isNotEmpty ? title : "${t.translate("diet_meal")} $idx",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: t.translate("diet_add_item"),
                                  onPressed: mealId <= 0
                                      ? null
                                      : () async {
                                          final userId = await AccountStorage.getUserId();
                                          if (userId == null) return;
                                          if (!context.mounted) return;

                                          final mealTitle = title.isNotEmpty
                                              ? title
                                              : "${t.translate("diet_meal")} $idx";
                                          final trainingDayId = _modeIndex == 1
                                              ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
                                              : null;

                                          // Show options first
                                          await showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: AppColors.black,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                                            ),
                                            builder: (_) => DietLoggingOptionsSheet(
                                              mealTitle: mealTitle,
                                              onSearch: () async {
                                                if (!context.mounted) return;
                                                await showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: AppColors.black,
                                                  shape: const RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                                                  ),
                                                  builder: (_) => DietItemSearchSheet(
                                                    rootContext: context,
                                                    userId: userId,
                                                    mealId: mealId,
                                                    mealTitle: mealTitle,
                                                    trainingDayId: trainingDayId,
                                                    initialTab: 0,
                                                    onLogged: (daySummary) async {
                                                      try {
                                                        if (daySummary != null && _meals != null && mounted) {
                                                          setState(() {
                                                            _meals = {
                                                              ..._meals!,
                                                              "day_summary": daySummary,
                                                            };
                                                          });
                                                        }
                                                        if (mounted) await _loadMeals();
                                                      } catch (_) {
                                                        if (mounted) await _loadMeals();
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                              onManualEntry: () async {
                                                if (!context.mounted) return;
                                                await showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: AppColors.black,
                                                  shape: const RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                                                  ),
                                                  builder: (_) => DietManualEntrySheet(
                                                    rootContext: context,
                                                    userId: userId,
                                                    mealId: mealId,
                                                    mealTitle: mealTitle,
                                                    trainingDayId: trainingDayId,
                                                    onLogged: (daySummary) async {
                                                      try {
                                                        if (daySummary != null && _meals != null && mounted) {
                                                          setState(() {
                                                            _meals = {
                                                              ..._meals!,
                                                              "day_summary": daySummary,
                                                            };
                                                          });
                                                        }
                                                        if (mounted) await _loadMeals();
                                                      } catch (_) {
                                                        if (mounted) await _loadMeals();
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                              onPhotoEntry: () async {
                                                if (!context.mounted) return;
                                                await showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: AppColors.black,
                                                  shape: const RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                                                  ),
                                                  builder: (_) => DietPhotoEntrySheet(
                                                    rootContext: context,
                                                    userId: userId,
                                                    mealId: mealId,
                                                    mealTitle: mealTitle,
                                                    trainingDayId: trainingDayId,
                                                    onLogged: (daySummary) async {
                                                      try {
                                                        if (daySummary != null && _meals != null && mounted) {
                                                          setState(() {
                                                            _meals = {
                                                              ..._meals!,
                                                              "day_summary": daySummary,
                                                            };
                                                          });
                                                        }
                                                        if (mounted) await _loadMeals();
                                                      } catch (_) {
                                                        if (mounted) await _loadMeals();
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.add, color: Colors.white70),
                                ),
                                Text(
                                  "$items $itemsLabel",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _macroChip(
                                  label: t.translate("diet_kcal_label"),
                                  grams: sums["calories"] ?? 0,
                                  unit: "kcal",
                                  color: cs.primary,
                                  icon: Icons.local_fire_department,
                                ),
                                _macroChip(
                                  label: t.translate("diet_p_short"),
                                  grams: sums["protein_g"] ?? 0,
                                  color: AppColors.accent,
                                  icon: Icons.fitness_center,
                                ),
                                _macroChip(
                                  label: t.translate("diet_c_short"),
                                  grams: sums["carbs_g"] ?? 0,
                                  color: AppColors.successGreen,
                                  icon: Icons.bolt,
                                ),
                                _macroChip(
                                  label: t.translate("diet_f_short"),
                                  grams: sums["fat_g"] ?? 0,
                                  color: const Color(0xFFFFA726),
                                  icon: Icons.opacity,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t.translate("diet_add_item_help"),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Placeholder for upcoming diet content
          CardContainer(
            child: Text(
              t.translate("diet_more_features_coming"),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingDayPicker(ThemeData theme, {VoidCallback? onChanged}) {
    final t = AppLocalizations.of(context);
    final days = _trainingDays;
    if (days.isEmpty) {
      return Text(
        t.translate("diet_training_day_targets_unavailable"),
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
      );
    }

    final items = <DropdownMenuItem<int>>[];
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final label = _asString(d["day_label"]);
      final dayId = _asInt(d["day_id"], fallback: i + 1);
      items.add(
        DropdownMenuItem(
          value: i,
          child: Text(
            label.isNotEmpty ? label : "${t.translate("diet_day")} $dayId",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedTrainingDayIndex.clamp(0, items.length - 1),
          items: items,
          isExpanded: true,
          dropdownColor: AppColors.cardDark,
          iconEnabledColor: Colors.white70,
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _selectedTrainingDayIndex = v);
            // If user is on training mode, persist calendar mapping for today.
            if (_modeIndex == 1) {
              try {
                final userId = await AccountStorage.getUserId();
                if (userId != null) {
                  final tdId = _asInt(_selectedTrainingDay?["day_id"], fallback: 0);
                  await TrainingCalendarService.setDay(
                    userId: userId,
                    entryDate: _mealDate,
                    dayType: 'training',
                    trainingDayId: tdId > 0 ? tdId : 1,
                  );
                }
              } catch (_) {
                // ignore
              }
            }
            onChanged?.call();
          },
        ),
      ),
    );
  }

  Widget _buildDaySummaryCard(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final live = _daySummaryLive;
    final target = (live?["target"] is Map) ? (live?["target"] as Map).cast<String, dynamic>() : null;
    final consumed = (live?["consumed"] is Map) ? (live?["consumed"] as Map).cast<String, dynamic>() : null;
    final remaining = (live?["remaining"] is Map) ? (live?["remaining"] as Map).cast<String, dynamic>() : null;

    final remCal = _dsInt(remaining, "calories");
    final tarCal = _dsInt(target, "calories");
    final conCal = _dsInt(consumed, "calories");

    final frozen = _daySummarySnapshot != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.translate("diet_remaining_title"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (frozen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    t.translate("diet_frozen_badge"),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$remCal",
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  t.translate("diet_kcal_unit"),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                "${t.translate("diet_consumed")}: $conCal / $tarCal",
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _macroChip(
                label: t.translate("diet_p_short"),
                grams: _dsInt(remaining, "protein_g"),
                color: AppColors.accent,
                icon: Icons.fitness_center,
              ),
              _macroChip(
                label: t.translate("diet_c_short"),
                grams: _dsInt(remaining, "carbs_g"),
                color: AppColors.successGreen,
                icon: Icons.bolt,
              ),
              _macroChip(
                label: t.translate("diet_f_short"),
                grams: _dsInt(remaining, "fat_g"),
                color: const Color(0xFFFFA726),
                icon: Icons.opacity,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: frozen || _freezing ? null : _freezeDay,
              child: _freezing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(frozen ? t.translate("diet_day_already_frozen") : t.translate("diet_freeze_day")),
            ),
          ),
          if (!frozen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.translate("diet_freeze_note"),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ),
          if (frozen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.translate("diet_frozen_note"),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ),
        ],
      ),
    );
  }
}