import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/account_storage.dart';
import '../../core/diet_regeneration_flag.dart';
import '../../localization/app_localizations.dart';
import '../../services/diet/diet_service.dart';
import '../../services/diet/diet_meals_storage.dart';
import '../../services/diet/diet_day_summary_storage.dart';
import '../../services/coach/diet_document_file_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/diet_item_search_sheet.dart';
import '../../widgets/diet_logging_options_sheet.dart';
import '../../widgets/diet_manual_entry_sheet.dart';
import '../../widgets/diet_photo_entry_sheet.dart';
import '../../widgets/diet_favorites_sheet.dart';
import '../../services/training/training_completion_storage.dart';
import '../../services/training/training_calendar_service.dart';
import '../../services/core/navigation_service.dart';
import '../../widgets/diet_recommendation_dialog.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/components/taqa_value_dialog.dart';
import '../../TaqaUI/components/taqa_steps_ui.dart'
    show TaqaTagButton, TaqaRangeTab;
import '../../TaqaUI/components/taqa_progress_widget_card.dart';
import '../../TaqaUI/components/taqa_record_dot.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => DietPageState();
}

class DietPageState extends State<DietPage> {
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _targets;
  bool _targetsFromCache = false;

  /// When diet is generating in background, we poll until targets appear.
  Timer? _targetsPollTimer;

  bool _mealsLoading = true;
  String? _mealsError;
  Map<String, dynamic>? _meals;
  DateTime _mealDate = _dateOnly(DateTime.now());
  bool _mealsFromCache = false;
  bool _freezing = false;
  int _mealsRequestId = 0;
  bool _manualMealDialogOpen = false;
  bool _itemSearchSheetOpen = false;
  bool _manualEntrySheetOpen = false;
  bool _photoEntrySheetOpen = false;
  bool _dietRecommendationShown = false;
  bool _loadingUploadedPlans = false;
  int _unseenDietTargetChangeCount = 0;

  int _modeIndex = 0; // 0 = Rest, 1 = Training
  bool _editingTargets = false;

  Future<void> _openEditTargetsSheet() async {
    if (_targets == null || _editingTargets) return;
    setState(() => _editingTargets = true);
    try {
      final result = await Navigator.of(context).push<_EditDietTargetsResult>(
        MaterialPageRoute(
          builder: (_) => _EditDietTargetsPage(
            restCalories: _asInt(_targets?["rest_calories"]),
            restProtein: _asInt(_targets?["rest_protein_g"]),
            restCarbs: _asInt(_targets?["rest_carbs_g"]),
            restFat: _asInt(_targets?["rest_fat_g"]),
            trainingDays: _trainingDays,
          ),
        ),
      );
      if (result != null) {
        await _submitEditedTargetValues(result);
      }
    } finally {
      if (mounted) {
        setState(() => _editingTargets = false);
      } else {
        _editingTargets = false;
      }
    }
  }

  Future<bool> _submitEditedTargetValues(_EditDietTargetsResult result) async {
    final t = AppLocalizations.of(context);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return false;

      final oCal = _asInt(_targets?["rest_calories"]);
      final oP = _asInt(_targets?["rest_protein_g"]);
      final oC = _asInt(_targets?["rest_carbs_g"]);
      final oF = _asInt(_targets?["rest_fat_g"]);
      Map<String, dynamic>? rest;
      if (result.restCalories != oCal ||
          result.restProtein != oP ||
          result.restCarbs != oC ||
          result.restFat != oF) {
        rest = {
          if (result.restCalories != oCal) "calories": result.restCalories,
          if (result.restProtein != oP) "protein_g": result.restProtein,
          if (result.restCarbs != oC) "carbs_g": result.restCarbs,
          if (result.restFat != oF) "fat_g": result.restFat,
        };
      }

      final days = <int, Map<String, dynamic>>{
        for (final d in _trainingDays) _asInt(d["day_id"], fallback: 0): d,
      };
      final trainingDays = <Map<String, dynamic>>[];
      for (final entry in result.trainingDays) {
        final dayId = _asInt(entry["day_id"], fallback: 0);
        final d = days[dayId];
        if (d == null) continue;
        final oDayCal = _asInt(d["train_calories"]);
        final oDayP = _asInt(d["train_protein_g"]);
        final oDayC = _asInt(d["train_carbs_g"]);
        final oDayF = _asInt(d["train_fat_g"]);
        final cal = _asInt(entry["calories"]);
        final p = _asInt(entry["protein_g"]);
        final c = _asInt(entry["carbs_g"]);
        final f = _asInt(entry["fat_g"]);
        final patch = <String, dynamic>{"day_id": dayId};
        if (cal != oDayCal) patch["calories"] = cal;
        if (p != oDayP) patch["protein_g"] = p;
        if (c != oDayC) patch["carbs_g"] = c;
        if (f != oDayF) patch["fat_g"] = f;
        if (patch.length > 1) trainingDays.add(patch);
      }

      if (rest == null && trainingDays.isEmpty) {
        AppToast.show(
          context,
          "No target changes detected.",
          type: AppToastType.info,
        );
        return false;
      }

      final updated = await DietService.patchTargets(
        userId: userId,
        rest: rest,
        trainingDays: trainingDays.isEmpty ? null : trainingDays,
      );

      if (!mounted) return false;
      setState(() {
        _targets = updated;
      });

      // Also refresh day summary / remaining via bootstrap or day-summary
      await _loadMeals(clearExisting: true);

      AppToast.show(
        context,
        t.translate("diet_edit_targets_save"),
        type: AppToastType.success,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      AppToast.show(
        context,
        e.toString().replaceFirst("Exception: ", ""),
        type: AppToastType.error,
      );
      return false;
    }
  }

  int _selectedTrainingDayIndex = 0;

  static const int _cardioLockMinDurationMinutes = 15;

  /// When true, user completed a strength/resistance exercise today so we force "training day".
  bool _trainDayLockedByExercise = false;

  /// When true, user completed >=15 min cardio today so we force "rest day" (relabeled as "cardio day").
  bool _restDayLockedByCardio = false;
  int? _lockedTrainingDayId;
  String? _lockedTrainingDayLabel;

  static bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _init();
    DietService.onTargetsUpdatedAfterBurn = _onTargetsUpdatedAfterBurn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowDietRecommendation();
    });
  }

  Future<void> _init() async {
    await _hydrateFromCache();
    await _loadBootstrap(silent: _targets != null || _meals != null);
    await _updateTrainingLockFromCompletion();
    await _refreshDietTargetChangeState(markSeen: false);
  }

  Future<void> _hydrateFromCache() async {
    try {
      final cachedTargets = await DietService.fetchCurrentTargetsFromCache();
      final trainingDayId = _modeIndex == 1
          ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
          : null;
      final effectiveTdId = (trainingDayId != null && trainingDayId > 0)
          ? trainingDayId
          : null;
      var cachedMeals = await DietService.fetchMealsForDateFromCache(
        _mealDate,
        trainingDayId: effectiveTdId,
      );
      if (cachedMeals != null && cachedMeals["day_summary"] == null) {
        try {
          final cachedSummary = await DietDaySummaryStorage.loadSummaryForDate(
            _mealDate,
          );
          if (cachedSummary != null) {
            cachedMeals = Map<String, dynamic>.from(cachedMeals);
            cachedMeals["day_summary"] = cachedSummary;
          }
        } catch (_) {
          // Ignore cached summary errors
        }
      }
      if (!mounted) return;
      setState(() {
        if (_targets == null && cachedTargets != null) {
          _targets = cachedTargets;
          // Cache-first hydration should not imply offline mode.
          // We only mark offline after a network request fails.
          _targetsFromCache = false;
          _loading = false;
        }
        if (_meals == null && cachedMeals != null) {
          _meals = cachedMeals;
          // Cache-first hydration should not imply offline mode.
          _mealsFromCache = false;
          _mealsLoading = false;
        }
      });
    } catch (_) {
      // ignore cache load errors
    }
  }

  void _onTargetsUpdatedAfterBurn() {
    if (mounted) refreshTargetsAndMeals();
  }

  /// Remaining calories from the locally-cached day summary, if known.
  /// Lets the recommendation dialog show "you have X kcal left" instantly,
  /// before the network call for food options resolves.
  int? _cachedRemainingCalories() {
    final summary = (_meals?["day_summary"] is Map)
        ? _meals!["day_summary"] as Map
        : null;
    if (summary == null) return null;
    final live = (summary["live"] is Map) ? summary["live"] as Map : summary;
    final remaining = (live["remaining"] is Map) ? live["remaining"] as Map : null;
    final dynamic cal = remaining?["calories"] ?? live["remaining_calories"];
    if (cal == null) return null;
    if (cal is int) return cal;
    if (cal is num) return cal.toInt();
    return int.tryParse(cal.toString().trim());
  }

  Future<void> _maybeShowDietRecommendation() async {
    if (_dietRecommendationShown) return;
    final shouldShow = NavigationService.consumeDietNotification();
    if (!shouldShow) return;
    _dietRecommendationShown = true;

    final userId = await AccountStorage.getUserId();
    if (userId == null || !mounted) return;

    // Kick off the fetch immediately, but open the dialog right away with the
    // remaining-calorie number we already have cached — no blank "please wait".
    final optionsFuture = DietService.fetchRemainingRecommendations(userId).then(
      (data) {
        final rec = (data["recommendation"] is Map)
            ? data["recommendation"] as Map
            : const {};
        final message =
            (rec["message"] ?? "Here are a few ideas to finish your day.")
                .toString();
        final optionsRaw = rec["options"];
        final options = (optionsRaw is List)
            ? optionsRaw
                  .whereType<Map>()
                  .map((e) => e.cast<String, dynamic>())
                  .toList()
            : <Map<String, dynamic>>[];
        return DietRecommendationResult(message: message, options: options);
      },
    );
    // Swallow the error here so an unawaited rejection doesn't surface; the
    // dialog's own catchError renders the failure state to the user.
    optionsFuture.catchError(
      (_) => const DietRecommendationResult(message: "", options: []),
    );

    await showDietRecommendationDialog(
      context: context,
      title: "Diet Suggestions",
      remainingCalories: _cachedRemainingCalories(),
      optionsFuture: optionsFuture,
    );
  }

  @override
  void dispose() {
    DietService.onTargetsUpdatedAfterBurn = null;
    _targetsPollTimer?.cancel();
    _targetsPollTimer = null;
    super.dispose();
  }

  /// Call when user switches to diet tab (e.g. after finishing a workout) so we refresh lock state.
  Future<void> refreshTrainingLock() async {
    await _updateTrainingLockFromCompletion();
  }

  /// Refetch targets and meals from backend so surplus (from calories burned) is visible without manual refresh.
  /// Refreshes silently in the background — existing data stays visible (no spinners).
  Future<void> refreshTargetsAndMeals() async {
    await _loadBootstrap(silent: true);
  }

  Future<void> syncSelectedDate(DateTime date, {bool refresh = true}) async {
    final normalized = _dateOnly(date);
    if (_sameCalendarDay(_mealDate, normalized)) {
      if (refresh) {
        await refreshTrainingLock();
        await refreshTargetsAndMeals();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _mealDate = normalized;
        _modeIndex = 0;
        _trainDayLockedByExercise = false;
        _restDayLockedByCardio = false;
        _lockedTrainingDayId = null;
        _lockedTrainingDayLabel = null;
        _meals = null;
        _mealsError = null;
        _mealsFromCache = false;
        _mealsLoading = true;
        _freezing = false;
      });
    } else {
      _mealDate = normalized;
      _modeIndex = 0;
      _trainDayLockedByExercise = false;
      _restDayLockedByCardio = false;
      _lockedTrainingDayId = null;
      _lockedTrainingDayLabel = null;
      _meals = null;
      _mealsError = null;
      _mealsFromCache = false;
      _mealsLoading = true;
      _freezing = false;
    }

    await _hydrateFromCache();
    if (!mounted || !_sameCalendarDay(_mealDate, normalized)) return;

    await _loadBootstrap(silent: false);
    if (!mounted || !_sameCalendarDay(_mealDate, normalized)) return;

    await _updateTrainingLockFromCompletion();
  }

  Future<void> _updateTrainingLockFromCompletion() async {
    final viewingToday = _sameCalendarDay(_mealDate, DateTime.now());
    if (!viewingToday) {
      if (mounted) {
        setState(() {
          _trainDayLockedByExercise = false;
          _restDayLockedByCardio = false;
          _lockedTrainingDayId = null;
          _lockedTrainingDayLabel = null;
        });
      }
      return;
    }
    final cardioLocked =
        await TrainingCompletionStorage.didCompleteCardioAtLeastMinutesOnDate(
          _mealDate,
          minDurationMinutes: _cardioLockMinDurationMinutes,
        );
    final didComplete = cardioLocked
        ? false
        : await TrainingCompletionStorage.didCompleteExerciseOnDate(_mealDate);
    final lockedDay = didComplete
        ? await TrainingCompletionStorage.getCompletedTrainingDayForDate(
            _mealDate,
          )
        : null;
    final lockedIdRaw = lockedDay?["training_day_id"];
    final lockedId = lockedIdRaw is num
        ? lockedIdRaw.toInt()
        : int.tryParse(lockedIdRaw?.toString() ?? "");
    final lockedLabel = lockedDay?["training_day_label"]?.toString();
    if (!mounted) return;
    setState(() {
      _restDayLockedByCardio = cardioLocked;
      _trainDayLockedByExercise = didComplete;
      _lockedTrainingDayId = (lockedId != null && lockedId > 0)
          ? lockedId
          : null;
      _lockedTrainingDayLabel =
          (lockedLabel != null && lockedLabel.trim().isNotEmpty)
          ? lockedLabel.trim()
          : null;
      if (cardioLocked) {
        _modeIndex = 0;
      } else if (didComplete) {
        _modeIndex = 1;
      }
    });

    if (cardioLocked) {
      // Keep backend day-type mapping aligned with locked rest/cardio mode.
      try {
        final userId = await AccountStorage.getUserId();
        if (userId != null) {
          await TrainingCalendarService.setDay(
            userId: userId,
            entryDate: _mealDate,
            dayType: 'rest',
          );
        }
      } catch (_) {
        // ignore mapping errors
      }
    }

    if (didComplete && _trainingDays.isNotEmpty) {
      setState(() {
        _selectedTrainingDayIndex = _resolveTrainingDayIndex(
          _trainingDays,
          fallback: _selectedTrainingDayIndex,
        );
      });
    }
    if (cardioLocked || didComplete) _loadMeals(clearExisting: true);
  }

  int _resolveTrainingDayIndex(
    List<Map<String, dynamic>> days, {
    int fallback = 0,
  }) {
    if (days.isEmpty) return 0;
    if (_trainDayLockedByExercise) {
      if (_lockedTrainingDayId != null && _lockedTrainingDayId! > 0) {
        final idx = days.indexWhere(
          (d) => _asInt(d["day_id"], fallback: 0) == _lockedTrainingDayId,
        );
        if (idx >= 0) return idx;
      }
      final label = (_lockedTrainingDayLabel ?? "").trim().toLowerCase();
      if (label.isNotEmpty) {
        final idx = days.indexWhere(
          (d) => _asString(d["day_label"]).trim().toLowerCase() == label,
        );
        if (idx >= 0) return idx;
      }
    }
    return fallback.clamp(0, days.length - 1);
  }

  List<Map<String, dynamic>> _trainingDaysFromTargets(
    Map<String, dynamic>? targets,
  ) {
    final list = targets?["training_day_targets"];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  static String? _readSectionError(
    Map<String, dynamic> payload,
    String section,
  ) {
    final keys = <String>[
      '${section}_error',
      '${section}Error',
      '${section}_detail',
      '${section}Detail',
    ];
    for (final k in keys) {
      final v = payload[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  Future<void> _loadBootstrap({bool silent = false}) async {
    _mealsRequestId++;
    final requestId = _mealsRequestId;
    final hasExistingTargets = _targets != null;
    final hasExistingMeals = _meals != null;
    setState(() {
      if (!silent && !hasExistingTargets) _loading = true;
      if (!silent && !hasExistingMeals) _mealsLoading = true;
      _error = null;
      _mealsError = null;
      _targetsFromCache = false;
      _mealsFromCache = false;
    });

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        throw Exception("User not found");
      }

      final trainingDayId = _modeIndex == 1
          ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
          : null;
      final effectiveTdId = (trainingDayId != null && trainingDayId > 0)
          ? trainingDayId
          : null;

      final payload = await DietService.fetchDietBootstrap(
        userId,
        date: _mealDate,
        autoGenerateTargets: true,
        autoOpenMeals: true,
        trainingDayId: effectiveTdId,
      );
      if (!mounted || requestId != _mealsRequestId) return;

      final targets = payload["targets"];
      final meals = payload["meals"];
      final targetsData = targets is Map
          ? targets.cast<String, dynamic>()
          : null;
      final mealsData = meals is Map ? meals.cast<String, dynamic>() : null;
      final targetsErr = _readSectionError(payload, 'targets');
      final mealsErr = _readSectionError(payload, 'meals');

      if (mealsData != null && mealsData["day_summary"] == null) {
        try {
          final summary = await DietService.fetchDaySummary(
            userId,
            date: _mealDate,
            trainingDayId: effectiveTdId,
          );
          mealsData["day_summary"] = summary;
          try {
            await DietMealsStorage.saveMealsForDate(
              _mealDate,
              mealsData.cast<String, dynamic>(),
              trainingDayId: effectiveTdId,
            );
          } catch (_) {
            // Ignore cache save errors
          }
        } catch (_) {
          // Ignore summary fetch errors.
        }
      }

      if (!mounted || requestId != _mealsRequestId) return;

      // Check if targets are stale (diet regenerating in background)
      final isStale = targetsData != null && targetsData['stale'] == true;

      if (mealsData != null) {
        setState(() {
          _meals = mealsData;
          _mealsLoading = false;
          _mealsError = null;
          _mealsFromCache = false;
        });
      } else {
        setState(() {
          _mealsLoading = false;
          _mealsError = mealsErr ?? _mealsError;
        });
      }

      if (isStale) {
        // Show stale targets immediately, then refresh in the background.
        final selectedIdx = _resolveTrainingDayIndex(
          _trainingDaysFromTargets(targetsData),
          fallback: _selectedTrainingDayIndex,
        );
        setState(() {
          _targets = targetsData;
          _selectedTrainingDayIndex = selectedIdx;
          _loading = false;
          _error = null;
          _targetsFromCache = false;
        });
        _targetsPollTimer?.cancel();
        _targetsPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted) return;
          _loadTargets(forceNetwork: true);
        });
        return;
      }

      if (targetsData != null && !isStale) {
        DietRegenerationFlag.clear();
      }

      setState(() {
        if (targetsData != null) {
          final selectedIdx = _resolveTrainingDayIndex(
            _trainingDaysFromTargets(targetsData),
            fallback: _selectedTrainingDayIndex,
          );
          _targets = targetsData;
          _selectedTrainingDayIndex = selectedIdx;
        }
        _loading = false;
        _error = targetsData == null ? (targetsErr ?? _error) : null;
        _targetsFromCache = false;
      });

      // Keep meal widgets usable even if targets section is unavailable.
      if (targetsData == null && mealsData != null) {
        return;
      }
    } catch (_) {
      // Bootstrap failed: keep existing fallback loaders.
      await _loadMeals();
      if (!mounted) return;
      await _loadTargets(forceNetwork: true);
    }
  }

  Future<void> _loadTargets({bool forceNetwork = true}) async {
    final hasExistingTargets = _targets != null;
    setState(() {
      // Only show loading spinner on first load; otherwise refresh silently.
      if (!hasExistingTargets) _loading = true;
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

      final isStale = data['stale'] == true;

      // While diet is regenerating in background, keep polling until backend
      // reports fresh targets.
      if (isStale) {
        // Keep stale targets visible while polling for fresh data.
        _targetsPollTimer?.cancel();
        _targetsPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted) return;
          _loadTargets(forceNetwork: true);
        });
        setState(() {
          final selectedIdx = _resolveTrainingDayIndex(
            _trainingDaysFromTargets(data),
            fallback: _selectedTrainingDayIndex,
          );
          _targets = data;
          _loading = false;
          _error = null;
          _targetsFromCache = false;
          _selectedTrainingDayIndex = selectedIdx;
        });
        return;
      }
      DietRegenerationFlag.clear();
      _targetsPollTimer?.cancel();
      _targetsPollTimer = null;
      setState(() {
        final selectedIdx = _resolveTrainingDayIndex(
          _trainingDaysFromTargets(data),
          fallback: _selectedTrainingDayIndex,
        );
        _targets = data;
        _loading = false;
        _error = null;
        _targetsFromCache = false;
        _selectedTrainingDayIndex = selectedIdx;
      });
    } catch (e) {
      // Cache fallback (offline-friendly)
      try {
        final cached = await DietService.fetchCurrentTargetsFromCache();
        if (!mounted) return;
        if (cached != null) {
          _targetsPollTimer?.cancel();
          _targetsPollTimer = null;
          setState(() {
            final selectedIdx = _resolveTrainingDayIndex(
              _trainingDaysFromTargets(cached),
              fallback: _selectedTrainingDayIndex,
            );
            _targets = cached;
            _loading = false;
            _error = null;
            _targetsFromCache = true;
            _selectedTrainingDayIndex = selectedIdx;
          });
          return;
        }
      } catch (_) {
        // ignore cache load errors
      }

      // Keep existing targets visible and retry in background.
      if (!mounted) return;
      _targetsPollTimer?.cancel();
      _targetsPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        _loadTargets(forceNetwork: true);
      });
      setState(() {
        _loading = _targets == null;
        _error = null;
        _targetsFromCache = false;
      });
    }
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? "") ?? fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? "") ?? fallback;
  }

  static String _asString(dynamic v) => (v == null ? "" : v.toString()).trim();

  Future<void> _loadMeals({bool clearExisting = false}) async {
    _mealsRequestId++;
    final requestId = _mealsRequestId;
    // When in training mode, fetch meals for that training day so create/fetch match
    final trainingDayId = _modeIndex == 1
        ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
        : null;
    final effectiveTdId = (trainingDayId != null && trainingDayId > 0)
        ? trainingDayId
        : null;

    if (clearExisting) {
      // Try to hydrate from cache for the target day/type before showing loading.
      try {
        final cached = await DietService.fetchMealsForDateFromCache(
          _mealDate,
          trainingDayId: effectiveTdId,
        );
        if (cached != null && mounted) {
          setState(() {
            _meals = cached;
            // Keep existing UI while refresh is in-flight; do not show offline
            // until a real network fallback happens.
            _mealsFromCache = false;
            _mealsLoading = false;
          });
        }
      } catch (_) {
        // ignore cache load errors
      }
    }

    final hasExistingData = _meals != null;
    setState(() {
      // Only show loading spinner on first load or explicit clear;
      // otherwise refresh silently in the background to avoid widget flicker.
      if (!hasExistingData) _mealsLoading = true;
      _mealsError = null;
    });

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        throw Exception("User not found");
      }

      final data = await DietService.fetchMealsForDate(
        userId,
        date: _mealDate,
        autoOpen: true,
        trainingDayId: effectiveTdId,
      );
      if (!mounted || requestId != _mealsRequestId) return;

      // If day_summary isn't in response, fetch it separately
      if (data["day_summary"] == null) {
        try {
          final summary = await DietService.fetchDaySummary(
            userId,
            date: _mealDate,
          );
          data["day_summary"] = summary;
          try {
            await DietMealsStorage.saveMealsForDate(
              _mealDate,
              data.cast<String, dynamic>(),
              trainingDayId: effectiveTdId,
            );
          } catch (_) {
            // Ignore cache save errors
          }
        } catch (_) {
          // Ignore if summary fetch fails
        }
      }

      if (!mounted || requestId != _mealsRequestId) return;
      setState(() {
        _meals = data;
        _mealsLoading = false;
        _mealsError = null;
        _mealsFromCache = false;
      });
    } catch (e) {
      // Cache fallback (offline-friendly)
      try {
        final trainingDayId = _modeIndex == 1
            ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
            : null;
        final effectiveTdId = (trainingDayId != null && trainingDayId > 0)
            ? trainingDayId
            : null;
        final cached = await DietService.fetchMealsForDateFromCache(
          _mealDate,
          trainingDayId: effectiveTdId,
        );
        if (!mounted || requestId != _mealsRequestId) return;
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

      if (!mounted || requestId != _mealsRequestId) return;
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
      return list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  Map<String, dynamic>? get _selectedTrainingDay {
    final days = _trainingDays;
    if (days.isEmpty) return null;
    final idx = _selectedTrainingDayIndex.clamp(0, days.length - 1);
    return days[idx];
  }

  Widget _nutrientArcCard({
    required String title,
    required int value,
    required int target,
    required String unit,
    required bool dark,
    bool showRecordDot = false,
  }) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final goalText = target > 0 ? "$target $unit" : "--";
    return TaqaProgressWidgetCard(
      title: title,
      valueText: "$value",
      goalText: goalText,
      progress: progress,
      lightSurface: !dark,
      topRight: showRecordDot ? const TaqaRecordDot() : const SizedBox.shrink(),
    );
  }

  Widget _mealMacroPair({
    required int value,
    required String unit,
    required String label,
    required double gap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          "$value$unit",
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w400,
            height: 20 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        SizedBox(width: TaqaUiScale.w(gap)),
        Text(
          label,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 20 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ],
    );
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
    final completionLabel = _completionPercentLabel(grams, target);
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
            hasTarget
                ? "$label $grams / $target$unit$completionLabel"
                : "$label $grams$unit",
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
      return list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
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
    if (_daySummary != null &&
        (_daySummary!["target"] != null || _daySummary!["remaining"] != null)) {
      return _daySummary;
    }
    return null;
  }

  Map<String, dynamic>? get _daySummarySnapshot {
    final snap = _daySummary?["snapshot"];
    if (snap is Map) return snap.cast<String, dynamic>();
    return null;
  }

  List<Map<String, dynamic>> _mealItems(Map<String, dynamic> meal) {
    final list = meal["items"];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  int _mealItemId(Map<String, dynamic> item) {
    // Backend likely uses "id" for meal item primary key; fall back to other keys if present.
    return _asInt(
      item["meal_item_id"] ?? item["id"] ?? item["item_id"],
      fallback: 0,
    );
  }

  int _dsInt(Map<String, dynamic>? m, String key) =>
      _asInt(m?[key], fallback: 0);

  String _completionPercentLabel(int consumed, int? target) {
    if (target == null || target <= 0) return "";
    final percent = ((consumed / target) * 100).round();
    return " ($percent%)";
  }

  Future<void> _openAddIngredientDialog({
    required int mealItemId,
    required String itemName,
  }) async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    InputDecoration fieldDecoration({String? hintText}) {
      final borderSide = BorderSide(
        color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
      );
      return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: TaqaUiColors.unnamedColorE3e3e3,
        border: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: BorderSide(color: TaqaUiColors.unnamedColor1c1d17),
        ),
      );
    }

    Widget fieldLabel(String text) {
      return Padding(
        padding: EdgeInsets.only(bottom: TaqaUiScale.h(4)),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(12),
            fontWeight: FontWeight.w600,
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    final fieldTextStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      color: TaqaUiColors.unnamedColor1c1d17,
    );

    try {
      final res = await showDialog<bool>(
        context: context,
        barrierColor: const Color(0x66000000),
        builder: (ctx) {
          return Align(
            alignment: Alignment.center,
            child: Padding(
              padding: TaqaUiScale.symmetric(horizontal: 17),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.none,
                child: Container(
                  constraints: BoxConstraints(maxWidth: TaqaUiScale.w(356)),
                  padding: TaqaUiScale.insetsLTRB(17, 15, 17, 15),
                  decoration: BoxDecoration(
                    color: TaqaUiColors.white,
                    borderRadius: TaqaUiScale.radius(15),
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          t.translate("diet_add_ingredient"),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w700,
                            height: 25 / 15,
                            letterSpacing: 0,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(4)),
                        Text(
                          itemName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(13),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(16)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            fieldLabel(t.translate("diet_ingredient_name")),
                            TextFormField(
                              controller: nameCtrl,
                              style: fieldTextStyle,
                              decoration: fieldDecoration(),
                              validator: (v) {
                                final trimmed = v?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return t.translate(
                                    "diet_ingredient_name_required",
                                  );
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(10)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            fieldLabel(t.translate("diet_ingredient_amount")),
                            TextFormField(
                              controller: amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: fieldTextStyle,
                              decoration: fieldDecoration(
                                hintText: t.translate(
                                  "diet_ingredient_optional",
                                ),
                              ),
                              validator: (v) {
                                final trimmed = v?.trim() ?? '';
                                if (trimmed.isEmpty) return null;
                                final val = double.tryParse(trimmed);
                                if (val == null || val <= 0) {
                                  return t.translate(
                                    "diet_ingredient_amount_invalid",
                                  );
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(10)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            fieldLabel(t.translate("diet_ingredient_unit")),
                            TextFormField(
                              controller: unitCtrl,
                              style: fieldTextStyle,
                              decoration: fieldDecoration(
                                hintText: t.translate(
                                  "diet_ingredient_optional",
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(24)),
                        SizedBox(
                          height: TaqaUiScale.h(45),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(ctx).pop(false),
                                  child: Center(
                                    child: Text(
                                      t
                                          .translate("common_cancel")
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: TaqaUiScale.sp(10),
                                        fontWeight: FontWeight.w600,
                                        height: 12 / 10,
                                        letterSpacing: 0,
                                        color: TaqaUiColors.unnamedColor1c1d17,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Material(
                                color: TaqaUiColors.unnamedColorE4e93b,
                                borderRadius: TaqaUiScale.radius(5),
                                child: InkWell(
                                  borderRadius: TaqaUiScale.radius(5),
                                  onTap: () {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    Navigator.of(ctx).pop(true);
                                  },
                                  child: SizedBox(
                                    width: TaqaUiScale.w(159),
                                    height: TaqaUiScale.h(45),
                                    child: Center(
                                      child: Text(
                                        t
                                            .translate("diet_add_ingredient")
                                            .toUpperCase(),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily:
                                              TaqaUiFontFamilies.interTight,
                                          fontSize: TaqaUiScale.sp(10),
                                          fontWeight: FontWeight.w700,
                                          height: 12 / 10,
                                          letterSpacing: 0,
                                          color:
                                              TaqaUiColors.unnamedColor1c1d17,
                                        ),
                                      ),
                                    ),
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
            ),
          );
        },
      );

      if (res != true) return;

      final userId = await AccountStorage.getUserId();
      if (userId == null) return;

      final ingredients = [
        {
          'ingredient_name': nameCtrl.text.trim(),
          if (amountCtrl.text.trim().isNotEmpty)
            'amount': double.parse(amountCtrl.text.trim()),
          if (unitCtrl.text.trim().isNotEmpty) 'unit': unitCtrl.text.trim(),
        },
      ];
      await DietService.addIngredientsToMealItem(
        userId: userId,
        mealItemId: mealItemId,
        ingredients: ingredients,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("diet_ingredient_added"),
        type: AppToastType.success,
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("diet_ingredient_add_failed")}: $e",
        type: AppToastType.error,
      );
    } finally {
      nameCtrl.dispose();
      amountCtrl.dispose();
      unitCtrl.dispose();
    }
  }

  Future<void> _openFavoritesSheet({
    required int userId,
    required int mealId,
    required String mealTitle,
    required int? trainingDayId,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(15)),
        ),
      ),
      builder: (_) => DietFavoritesSheet(
        rootContext: context,
        userId: userId,
        mealId: mealId,
        mealTitle: mealTitle,
        trainingDayId: trainingDayId,
        onLogged: (daySummary) async {
          try {
            if (daySummary != null && _meals != null && mounted) {
              setState(() {
                _meals = {..._meals!, "day_summary": daySummary};
              });
            }
            if (mounted) await _loadMeals();
          } catch (_) {
            if (mounted) await _loadMeals();
          }
        },
      ),
    );
  }

  Future<void> _saveMealAsFavorite({
    required int userId,
    required Map<String, dynamic> meal,
    required String mealTitle,
    int? trainingDayId,
  }) async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: mealTitle);
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    InputDecoration fieldDecoration({String? hintText}) {
      final borderSide = BorderSide(
        color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
      );
      return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: TaqaUiColors.unnamedColorE3e3e3,
        border: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: BorderSide(color: TaqaUiColors.unnamedColor1c1d17),
        ),
      );
    }

    Widget fieldLabel(String text) {
      return Padding(
        padding: EdgeInsets.only(bottom: TaqaUiScale.h(4)),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(12),
            fontWeight: FontWeight.w600,
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    final fieldTextStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      color: TaqaUiColors.unnamedColor1c1d17,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) {
        return Align(
          alignment: Alignment.center,
          child: Padding(
            padding: TaqaUiScale.symmetric(horizontal: 17),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.none,
              child: Container(
                constraints: BoxConstraints(maxWidth: TaqaUiScale.w(356)),
                padding: TaqaUiScale.insetsLTRB(17, 15, 17, 15),
                decoration: BoxDecoration(
                  color: TaqaUiColors.white,
                  borderRadius: TaqaUiScale.radius(15),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        t.translate("diet_favorites_save_title"),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(15),
                          fontWeight: FontWeight.w700,
                          height: 25 / 15,
                          letterSpacing: 0,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(16)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fieldLabel(t.translate("diet_favorites_name")),
                          TextFormField(
                            controller: nameCtrl,
                            style: fieldTextStyle,
                            decoration: fieldDecoration(),
                            validator: (v) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return t.translate(
                                  "diet_favorites_name_required",
                                );
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: TaqaUiScale.h(10)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fieldLabel(t.translate("diet_favorites_notes")),
                          TextFormField(
                            controller: notesCtrl,
                            style: fieldTextStyle,
                            decoration: fieldDecoration(),
                          ),
                        ],
                      ),
                      SizedBox(height: TaqaUiScale.h(24)),
                      SizedBox(
                        height: TaqaUiScale.h(45),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(false),
                                child: Center(
                                  child: Text(
                                    t.translate("common_cancel").toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(10),
                                      fontWeight: FontWeight.w600,
                                      height: 12 / 10,
                                      letterSpacing: 0,
                                      color: TaqaUiColors.unnamedColor1c1d17,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Material(
                              color: TaqaUiColors.unnamedColorE4e93b,
                              borderRadius: TaqaUiScale.radius(5),
                              child: InkWell(
                                borderRadius: TaqaUiScale.radius(5),
                                onTap: () {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  Navigator.of(ctx).pop(true);
                                },
                                child: SizedBox(
                                  width: TaqaUiScale.w(159),
                                  height: TaqaUiScale.h(45),
                                  child: Center(
                                    child: Text(
                                      t
                                          .translate("diet_favorites_save")
                                          .toUpperCase(),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: TaqaUiScale.sp(10),
                                        fontWeight: FontWeight.w700,
                                        height: 12 / 10,
                                        letterSpacing: 0,
                                        color: TaqaUiColors.unnamedColor1c1d17,
                                      ),
                                    ),
                                  ),
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
          ),
        );
      },
    );

    if (confirmed != true) return;

    final items = _mealItems(meal);
    if (items.isEmpty) {
      AppToast.show(
        context,
        t.translate("diet_favorites_empty_meal"),
        type: AppToastType.info,
      );
      return;
    }

    final payloadItems = items.asMap().entries.map((entry) {
      final index = entry.key; // 0-based
      final item = entry.value;
      final ingredients = item['ingredients'];
      final ingList = ingredients is List
          ? ingredients
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList()
          : <Map<String, dynamic>>[];
      final source = _asString(item['source']);
      return {
        'source': source.isNotEmpty ? source : 'manual',
        'item_name': _asString(item['item_name']),
        if (item['grams'] != null) 'grams': _asDouble(item['grams']),
        'calories': _asInt(item['calories']),
        'protein_g': _asInt(item['protein_g']),
        'carbs_g': _asInt(item['carbs_g']),
        'fat_g': _asInt(item['fat_g']),
        'is_estimated': item['is_estimated'] == true,
        'photo_url': item['photo_url'],
        'food_id': item['food_id'],
        // Backend requires item_order >= 1; use 1..N regardless of original value.
        'item_order': index + 1,
        if (ingList.isNotEmpty) 'ingredients': ingList,
      };
    }).toList();

    try {
      final newTitle = nameCtrl.text.trim();
      await DietService.createFavoriteMeal(
        userId: userId,
        mealName: newTitle,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        items: payloadItems,
      );

      final mealId = _asInt(meal["meal_id"], fallback: 0);
      if (mealId > 0 && newTitle != mealTitle) {
        await DietService.updateMeal(
          userId: userId,
          mealId: mealId,
          title: newTitle,
          trainingDayId: trainingDayId,
        );
        if (_meals != null) {
          for (final m in _mealList) {
            if (_asInt(m["meal_id"], fallback: 0) == mealId) {
              m["title"] = newTitle;
              break;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {});
      AppToast.show(
        context,
        t.translate("diet_favorites_saved"),
        type: AppToastType.success,
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("diet_favorites_save_failed")}: $e",
        type: AppToastType.error,
      );
    } finally {
      nameCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<void> _createMealManually() async {
    if (_manualMealDialogOpen) return;
    _manualMealDialogOpen = true;
    final t = AppLocalizations.of(context);
    try {
      final confirmed = await showTaqaConfirmDialog(
        context: context,
        title: t.translate("diet_add_meal_title"),
        message: t.translate("diet_add_meal_confirm_message"),
        confirmLabel: t.translate("diet_add_meal_confirm"),
        cancelLabel: t.translate("common_cancel"),
      );
      if (!confirmed) return;

      final userId = await AccountStorage.getUserId();
      if (userId == null) return;

      // Add one extra meal slot for this day; backend names it by order (Meal 4, etc.).
      final response = await DietService.addMealSlot(
        userId: userId,
        date: _mealDate,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("diet_add_meal_success"),
        type: AppToastType.success,
      );

      setState(() {
        _meals = Map<String, dynamic>.from(response);
        if (_meals!["meals"] == null && response["meals"] != null) {
          _meals!["meals"] = response["meals"];
        }
      });
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      AppToast.show(
        context,
        "${t.translate("diet_add_meal_failed")}: $msg",
        type: AppToastType.error,
      );
    } finally {
      _manualMealDialogOpen = false;
    }
  }

  Future<void> _deleteMeal({
    required int mealId,
    required String mealTitle,
    required List<Map<String, dynamic>> items,
    int? trainingDayId,
  }) async {
    final t = AppLocalizations.of(context);
    final itemCount = items.length;
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: t.translate("diet_delete_meal_title"),
      message:
          "${(itemCount > 0 ? t.translate("diet_delete_meal_confirm_has_items") : t.translate("diet_delete_meal_confirm_empty")).replaceAll("{meal}", mealTitle)}\n\n${t.translate("diet_delete_meal_note")}",
      confirmLabel: t.translate("diet_delete_meal_confirm"),
      cancelLabel: t.translate("common_cancel"),
    );
    if (!confirmed) return;

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      final response = await DietService.deleteMeal(
        userId: userId,
        mealId: mealId,
        trainingDayId: trainingDayId,
      );
      if (!mounted) return;
      final daySummary = response["day_summary"] is Map
          ? (response["day_summary"] as Map).cast<String, dynamic>()
          : null;
      if (_meals != null) {
        final updatedMeals = _mealList
            .where((m) => _asInt(m["meal_id"], fallback: 0) != mealId)
            .toList();
        setState(() {
          _meals = {
            ..._meals!,
            "meals": updatedMeals,
            if (daySummary != null) "day_summary": daySummary,
          };
        });
      }
      AppToast.show(
        context,
        t.translate("diet_delete_meal_success"),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("diet_delete_meal_failed")}: $e",
        type: AppToastType.error,
      );
    }
  }

  Future<void> _deleteMealItem({
    required int mealItemId,
    required String itemName,
  }) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: t.translate("diet_delete_item_title"),
      message: t
          .translate("diet_delete_item_confirm")
          .replaceAll("{item}", itemName),
      confirmLabel: t.translate("diet_delete_item_confirm_button"),
      cancelLabel: t.translate("common_cancel"),
    );
    if (!confirmed) return;

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      await DietService.deleteMealItem(userId: userId, mealItemId: mealItemId);
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("diet_delete_item_success"),
        type: AppToastType.success,
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("diet_delete_item_failed")}: $e",
        type: AppToastType.error,
      );
    }
  }

  Future<void> _clearMealItems({
    required List<Map<String, dynamic>> items,
    required String mealTitle,
  }) async {
    final t = AppLocalizations.of(context);
    if (items.isEmpty) return;
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: t.translate("diet_clear_meal_title"),
      message: t
          .translate("diet_clear_meal_confirm")
          .replaceAll("{meal}", mealTitle),
      confirmLabel: t.translate("diet_clear_meal_confirm_button"),
      cancelLabel: t.translate("common_cancel"),
    );
    if (!confirmed) return;

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      for (final item in items) {
        final itemId = _mealItemId(item);
        if (itemId <= 0) continue;
        await DietService.deleteMealItem(userId: userId, mealItemId: itemId);
      }
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("diet_clear_meal_success"),
        type: AppToastType.success,
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("diet_clear_meal_failed")}: $e",
        type: AppToastType.error,
      );
    }
  }

  Future<void> _renameMeal({
    required int mealId,
    required String currentTitle,
    int? trainingDayId,
  }) async {
    final t = AppLocalizations.of(context);

    final newTitle = await showTaqaTextValueDialog(
      context: context,
      title: t.translate("diet_rename_meal_dialog_title"),
      initialValue: currentTitle,
      keyboardType: TextInputType.text,
    );
    if (newTitle == null) return;
    if (newTitle.length > 120) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("diet_add_meal_name_too_long"),
        type: AppToastType.info,
      );
      return;
    }

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      await DietService.updateMeal(
        userId: userId,
        mealId: mealId,
        title: newTitle,
        trainingDayId: trainingDayId,
      );
      if (!mounted) return;

      // Optimistic update: immediately show the new title in local state
      if (_meals != null) {
        final meals = _mealList;
        for (final m in meals) {
          if (_asInt(m["meal_id"], fallback: 0) == mealId) {
            m["title"] = newTitle;
            break;
          }
        }
        setState(() {});
      }

      AppToast.show(
        context,
        t.translate("diet_rename_meal_success"),
        type: AppToastType.success,
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("diet_rename_meal_failed")}: $e",
        type: AppToastType.error,
      );
    }
  }

  Future<void> _freezeDay() async {
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    setState(() => _freezing = true);
    try {
      await DietService.captureDaySummary(userId, date: _mealDate);
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("diet_day_frozen"),
        type: AppToastType.success,
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("diet_freeze_failed")}: $e",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _freezing = false);
    }
  }

  /// Meal totals: from API when present (sum of items or user override), otherwise sum of items.
  Map<String, int> _mealTotals(Map<String, dynamic> meal) {
    final totals = meal["totals"];
    if (totals is Map) {
      return {
        "calories": _asInt(totals["calories"]),
        "protein_g": _asInt(totals["protein_g"]),
        "carbs_g": _asInt(totals["carbs_g"]),
        "fat_g": _asInt(totals["fat_g"]),
      };
    }
    return _sumMealItemsMacros(meal);
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

  String _formatUploadedPlanDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _formatDietTargetChangeDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$mm/$dd/$yyyy $hh:$min';
  }

  String _targetMetricLabel(String metric) {
    switch (metric.trim().toLowerCase()) {
      case 'calories':
        return 'Kcal';
      case 'protein_g':
        return 'Protein';
      case 'carbs_g':
        return 'Carbs';
      case 'fat_g':
        return 'Fat';
      default:
        return metric;
    }
  }

  String _targetChangeDetailText(Map<String, dynamic> detail) {
    final scope = (detail['scope'] ?? '').toString().trim().toLowerCase();
    final metric = _targetMetricLabel((detail['field'] ?? '').toString());
    final fromVal = detail['from']?.toString() ?? '-';
    final toVal = detail['to']?.toString() ?? '-';
    if (scope == 'training_day') {
      final dayLabel = (detail['day_label'] ?? '').toString().trim();
      final day = dayLabel.isEmpty ? 'Day' : dayLabel;
      return '$day • $metric: $fromVal -> $toVal';
    }
    return 'Rest • $metric: $fromVal -> $toVal';
  }

  String _coachFirstNameLabel(String? rawCoachName) {
    final raw = (rawCoachName ?? '').trim();
    if (raw.isEmpty) return 'Coach';

    String first = raw;
    if (raw.contains(RegExp(r'\s+'))) {
      first = raw.split(RegExp(r'\s+')).first;
    } else if (raw.contains(RegExp(r'[_\-.]+'))) {
      first = raw.split(RegExp(r'[_\-.]+')).first;
    }
    if (first.isNotEmpty) {
      return '${first[0].toUpperCase()}${first.substring(1)}';
    }
    return 'Coach';
  }

  Future<void> _openUploadedPlanDocument(
    DietCoachPlanDocument document, {
    required void Function(void Function()) setSheetState,
    required Set<int> openingIds,
  }) async {
    final documentId = document.documentId;
    if (openingIds.contains(documentId)) return;
    setSheetState(() => openingIds.add(documentId));
    try {
      final url = (document.documentUrl ?? '').trim();
      if (url.isEmpty) {
        throw Exception('Document URL is missing.');
      }
      final localPath =
          await DietDocumentFileService.prepareLocalDietDocumentFile(
            url,
            suggestedFileName:
                document.originalFilename ?? document.documentTitle,
          );
      var opened = false;
      try {
        opened = await launchUrl(
          Uri.file(localPath),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        final remoteUri = DietDocumentFileService.resolveUri(url);
        if (remoteUri != null) {
          opened = await launchUrl(
            remoteUri,
            mode: LaunchMode.externalApplication,
          );
        }
      }
      if (!opened) {
        throw Exception('Could not open downloaded plan on this device.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setSheetState(() => openingIds.remove(documentId));
      }
    }
  }

  Future<void> _refreshDietTargetChangeState({required bool markSeen}) async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) return;
      final payload = await DietService.fetchDietTargetChanges(
        userId: userId,
        markSeen: markSeen,
      );
      final unseen = payload['unseen_count'] is int
          ? payload['unseen_count'] as int
          : 0;
      if (!mounted) return;
      setState(() {
        _unseenDietTargetChangeCount = markSeen ? 0 : unseen;
      });
    } catch (_) {
      // Keep page responsive if update-log fetch fails.
    }
  }

  Future<void> _showUploadedPlansSheet() async {
    if (_loadingUploadedPlans) return;
    setState(() => _loadingUploadedPlans = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) {
        throw Exception('User not found.');
      }
      final plans = await DietService.fetchCoachPlanDocuments(
        userId: userId,
        markSeen: true,
      );
      final targetPayload = await DietService.fetchDietTargetChanges(
        userId: userId,
        markSeen: true,
      );
      final targetChanges =
          (targetPayload['items'] as List<DietTargetChangeEvent>? ?? const [])
              .toList(growable: false);
      if (mounted) {
        setState(() {
          _unseenDietTargetChangeCount = 0;
        });
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: TaqaUiColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TaqaUiScale.r(15)),
          ),
        ),
        builder: (sheetContext) {
          final openingIds = <int>{};
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: TaqaUiScale.insetsLTRB(16, 16, 16, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.78,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Uploaded Plans',
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(18),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Icon(
                                Icons.close,
                                color: TaqaUiColors.unnamedColor1c1d17,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(8)),
                        if (targetChanges.isEmpty && plans.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                'No plan updates yet.',
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  color: TaqaUiColors.unnamedColor1c1d17
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView(
                              children: [
                                if (targetChanges.isNotEmpty) ...[
                                  Text(
                                    'Target Updates',
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(12),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(4)),
                                  Text(
                                    'Note: Today\'s visible calories can include added burn surplus.',
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(11),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0,
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(8)),
                                  for (final event in targetChanges) ...[
                                    Container(
                                      padding: TaqaUiScale.insetsLTRB(
                                        14,
                                        10,
                                        14,
                                        15,
                                      ),
                                      margin: EdgeInsets.only(
                                        bottom: TaqaUiScale.h(8),
                                      ),
                                      decoration: BoxDecoration(
                                        color: TaqaUiColors.white,
                                        borderRadius: TaqaUiScale.radius(15),
                                        border: Border.all(
                                          color: event.isNew
                                              ? TaqaUiColors.unnamedColorE4e93b
                                              : TaqaUiColors.unnamedColor1c1d17
                                                    .withValues(alpha: 0.10),
                                          width: event.isNew ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event.summary,
                                            style: TextStyle(
                                              fontFamily:
                                                  TaqaUiFontFamilies.interTight,
                                              fontSize: TaqaUiScale.sp(15),
                                              fontWeight: FontWeight.w700,
                                              height: 25 / 15,
                                              letterSpacing: 0,
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17,
                                            ),
                                          ),
                                          if (event.createdAt != null) ...[
                                            SizedBox(height: TaqaUiScale.h(4)),
                                            Text(
                                              _formatDietTargetChangeDate(
                                                event.createdAt,
                                              ),
                                              style: TextStyle(
                                                fontFamily: TaqaUiFontFamilies
                                                    .interTight,
                                                fontSize: TaqaUiScale.sp(12),
                                                letterSpacing: 0,
                                                color: TaqaUiColors
                                                    .unnamedColor1c1d17
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                          ],
                                          if (event.details.isNotEmpty) ...[
                                            SizedBox(height: TaqaUiScale.h(8)),
                                            for (final detail
                                                in event.details.take(4)) ...[
                                              Text(
                                                _targetChangeDetailText(detail),
                                                style: TextStyle(
                                                  fontFamily: TaqaUiFontFamilies
                                                      .interTight,
                                                  fontSize: TaqaUiScale.sp(12),
                                                  letterSpacing: 0,
                                                  color: TaqaUiColors
                                                      .unnamedColor1c1d17
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                            if (event.details.length > 4)
                                              Text(
                                                '+${event.details.length - 4} more changes',
                                                style: TextStyle(
                                                  fontFamily: TaqaUiFontFamilies
                                                      .interTight,
                                                  fontSize: TaqaUiScale.sp(11),
                                                  letterSpacing: 0,
                                                  color: TaqaUiColors
                                                      .unnamedColor1c1d17
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                                if (plans.isNotEmpty) ...[
                                  if (targetChanges.isNotEmpty)
                                    SizedBox(height: TaqaUiScale.h(8)),
                                  Text(
                                    'Uploaded Plans',
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(12),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(8)),
                                  for (final plan in plans) ...[
                                    Builder(
                                      builder: (_) {
                                        final coachLabel = _coachFirstNameLabel(
                                          plan.coachName,
                                        );
                                        final isOpening = openingIds.contains(
                                          plan.documentId,
                                        );
                                        return Container(
                                          padding: TaqaUiScale.insetsLTRB(
                                            14,
                                            10,
                                            14,
                                            15,
                                          ),
                                          margin: EdgeInsets.only(
                                            bottom: TaqaUiScale.h(8),
                                          ),
                                          decoration: BoxDecoration(
                                            color: TaqaUiColors.white,
                                            borderRadius: TaqaUiScale.radius(
                                              15,
                                            ),
                                            border: Border.all(
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17
                                                  .withValues(alpha: 0.10),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.description_outlined,
                                                color: TaqaUiColors
                                                    .unnamedColor1c1d17
                                                    .withValues(alpha: 0.5),
                                                size: 18,
                                              ),
                                              SizedBox(
                                                width: TaqaUiScale.w(10),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            plan.displayTitle,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  TaqaUiFontFamilies
                                                                      .interTight,
                                                              fontSize:
                                                                  TaqaUiScale.sp(
                                                                    15,
                                                                  ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              height: 25 / 15,
                                                              letterSpacing: 0,
                                                              color: TaqaUiColors
                                                                  .unnamedColor1c1d17,
                                                            ),
                                                          ),
                                                        ),
                                                        if (plan.isPinned) ...[
                                                          SizedBox(
                                                            width:
                                                                TaqaUiScale.w(
                                                                  6,
                                                                ),
                                                          ),
                                                          Icon(
                                                            Icons.push_pin,
                                                            size: 14,
                                                            color: TaqaUiColors
                                                                .unnamedColor1c1d17,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    SizedBox(
                                                      height: TaqaUiScale.h(4),
                                                    ),
                                                    Text(
                                                      coachLabel,
                                                      style: TextStyle(
                                                        fontFamily:
                                                            TaqaUiFontFamilies
                                                                .interTight,
                                                        fontSize:
                                                            TaqaUiScale.sp(12),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: 0,
                                                        color: TaqaUiColors
                                                            .unnamedColor1c1d17
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: TaqaUiScale.h(2),
                                                    ),
                                                    Text(
                                                      _formatUploadedPlanDate(
                                                        plan.createdAt ??
                                                            plan.updatedAt,
                                                      ),
                                                      style: TextStyle(
                                                        fontFamily:
                                                            TaqaUiFontFamilies
                                                                .interTight,
                                                        fontSize:
                                                            TaqaUiScale.sp(12),
                                                        letterSpacing: 0,
                                                        color: TaqaUiColors
                                                            .unnamedColor1c1d17
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: TaqaUiScale.w(10),
                                              ),
                                              Material(
                                                color: TaqaUiColors
                                                    .unnamedColorE4e93b,
                                                borderRadius:
                                                    TaqaUiScale.radius(5),
                                                child: InkWell(
                                                  borderRadius:
                                                      TaqaUiScale.radius(5),
                                                  onTap: isOpening
                                                      ? null
                                                      : () =>
                                                            _openUploadedPlanDocument(
                                                              plan,
                                                              setSheetState:
                                                                  setSheetState,
                                                              openingIds:
                                                                  openingIds,
                                                            ),
                                                  child: Padding(
                                                    padding:
                                                        TaqaUiScale.insetsLTRB(
                                                          12,
                                                          8,
                                                          12,
                                                          8,
                                                        ),
                                                    child: isOpening
                                                        ? SizedBox(
                                                            width:
                                                                TaqaUiScale.w(
                                                                  12,
                                                                ),
                                                            height:
                                                                TaqaUiScale.h(
                                                                  12,
                                                                ),
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: TaqaUiColors
                                                                  .unnamedColor1c1d17,
                                                            ),
                                                          )
                                                        : Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .open_in_new,
                                                                size: 14,
                                                                color: TaqaUiColors
                                                                    .unnamedColor1c1d17,
                                                              ),
                                                              SizedBox(
                                                                width:
                                                                    TaqaUiScale.w(
                                                                      4,
                                                                    ),
                                                              ),
                                                              Text(
                                                                'OPEN',
                                                                style: TextStyle(
                                                                  fontFamily:
                                                                      TaqaUiFontFamilies
                                                                          .interTight,
                                                                  fontSize:
                                                                      TaqaUiScale.sp(
                                                                        10,
                                                                      ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  height:
                                                                      12 / 10,
                                                                  letterSpacing:
                                                                      0,
                                                                  color: TaqaUiColors
                                                                      .unnamedColor1c1d17,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _loadingUploadedPlans = false);
      }
    }
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

    // Get consumption data from day_summary if available
    final live = _daySummaryLive;
    final target = (live?["target"] is Map)
        ? (live?["target"] as Map).cast<String, dynamic>()
        : null;
    final consumed = (live?["consumed"] is Map)
        ? (live?["consumed"] as Map).cast<String, dynamic>()
        : null;

    final conCal = _dsInt(consumed, "calories");
    final tarCal = _dsInt(target, "calories");

    final targetsSubtitle =
        _error ??
        (_targetsFromCache
            ? t.translate("diet_offline_targets")
            : t.translate("diet_targets_subtitle"));

    final mealsSubtitleSuffix =
        _mealsError ??
        (_mealsFromCache ? t.translate("diet_offline_meals") : "");
    final mealsSubtitle = mealsSubtitleSuffix.isEmpty
        ? t.translate("diet_targets_subtitle")
        : "${t.translate("diet_targets_subtitle")} • $mealsSubtitleSuffix";

    final caloriesTarget = tarCal > 0 ? tarCal : activeCalories;
    final proteinTargetRaw = target != null ? _dsInt(target, "protein_g") : 0;
    final proteinTarget = proteinTargetRaw > 0 ? proteinTargetRaw : activeP;
    final proteinValue = consumed != null ? _dsInt(consumed, "protein_g") : 0;
    final carbsTargetRaw = target != null ? _dsInt(target, "carbs_g") : 0;
    final carbsTarget = carbsTargetRaw > 0 ? carbsTargetRaw : activeC;
    final carbsValue = consumed != null ? _dsInt(consumed, "carbs_g") : 0;
    final fatTargetRaw = target != null ? _dsInt(target, "fat_g") : 0;
    final fatTarget = fatTargetRaw > 0 ? fatTargetRaw : activeF;
    final fatValue = consumed != null ? _dsInt(consumed, "fat_g") : 0;

    return Container(
      color: TaqaUiColors.unnamedColorE3e3e3,
      child: SafeArea(
        child: ListView(
          padding: TaqaUiScale.insetsLTRB(16, 20, 16, 24),
          children: [
            Center(
              child: Text(
                t.translate("diet_title"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w700,
                  height: 25 / 15,
                  letterSpacing: 0,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(20)),

            // Mode toggle (can be locked to Training after strength, or locked to Rest/Cardio after >=15m cardio)
            Builder(
              builder: (context) {
                final primaryDayTitle = _restDayLockedByCardio
                    ? t.translate("diet_cardio_day")
                    : t.translate("diet_rest_day");
                Future<void> selectMode(int idx) async {
                  if (_trainDayLockedByExercise && idx == 0) {
                    return; // cannot switch to Rest when trained today
                  }
                  if (_restDayLockedByCardio && idx == 1) {
                    return; // cannot switch to Training when cardio lock is active
                  }
                  setState(() {
                    _modeIndex = idx;
                  });
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
                        final tdId = _asInt(
                          _selectedTrainingDay?["day_id"],
                          fallback: 0,
                        );
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
                  _loadMeals(clearExisting: true);
                  AccountStorage.notifyDietChanged();
                }

                return Row(
                  children: [
                    Expanded(
                      child: TaqaRangeTab(
                        label: primaryDayTitle,
                        selected: _modeIndex == 0,
                        onTap: () => selectMode(0),
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(15)),
                    Expanded(
                      child: TaqaRangeTab(
                        label: t.translate("diet_training_day"),
                        selected: _modeIndex == 1,
                        onTap: () => selectMode(1),
                      ),
                    ),
                  ],
                );
              },
            ),

            if (_modeIndex == 1) ...[
              const SizedBox(height: 12),
              _buildTrainingDayPicker(
                theme,
                onChanged: () => _loadMeals(clearExisting: true),
              ),
            ],

            SizedBox(height: TaqaUiScale.h(20)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    t.translate("diet_daily_targets"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(25),
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ),
                if (!_loadingUploadedPlans) ...[
                  TaqaTagButton(
                    icon: Icons.description_outlined,
                    label: _unseenDietTargetChangeCount > 0
                        ? "Plans $_unseenDietTargetChangeCount"
                        : "Plans",
                    onTap: _showUploadedPlansSheet,
                  ),
                  SizedBox(width: TaqaUiScale.w(8)),
                ],
                TaqaTagButton(
                  icon: Icons.tune,
                  label: t.translate("diet_edit_targets"),
                  onTap: () {
                    if (!_loading && _targets != null) {
                      _openEditTargetsSheet();
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            Text(
              targetsSubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w400,
                height: 18 / 15,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(20)),

            if (_loading || _targets == null) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                        t.translate("diet_preparing_plan"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: TaqaUiColors.unnamedColor1c1d17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // --- Nutrients (arc widgets reused from dashboard) ---
              Row(
                children: [
                  Expanded(
                    child: _nutrientArcCard(
                      title: t.translate("diet_manual_calories"),
                      value: conCal,
                      target: caloriesTarget,
                      unit: t.translate("diet_kcal_unit"),
                      dark: true,
                      showRecordDot: true,
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(15)),
                  Expanded(
                    child: _nutrientArcCard(
                      title: t.translate("protein"),
                      value: proteinValue,
                      target: proteinTarget,
                      unit: t.translate("diet_grams_unit"),
                      dark: false,
                    ),
                  ),
                ],
              ),
              SizedBox(height: TaqaUiScale.h(15)),
              Row(
                children: [
                  Expanded(
                    child: _nutrientArcCard(
                      title: t.translate("diet_carbs"),
                      value: carbsValue,
                      target: carbsTarget,
                      unit: t.translate("diet_grams_unit"),
                      dark: false,
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(15)),
                  Expanded(
                    child: _nutrientArcCard(
                      title: t.translate("diet_fat"),
                      value: fatValue,
                      target: fatTarget,
                      unit: t.translate("diet_grams_unit"),
                      dark: false,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // --- Today's Meals ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    t.translate("diet_today_meals"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(25),
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ),
                TaqaTagButton(
                  icon: Icons.add,
                  label: t.translate("diet_add_item_tag"),
                  onTap: () {
                    if (!_mealsLoading) _createMealManually();
                  },
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            Text(
              mealsSubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w300,
                height: 18 / 15,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(20)),

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
                  color: TaqaUiColors.unnamedColor1c1d17,
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
              ..._mealList.asMap().entries.map((entry) {
                final listIndex = entry.key;
                final meal = entry.value;
                final backendTitle = _asString(meal["title"]);
                final idx =
                    listIndex +
                    1; // Frontend display index (1..N) - always use this for numbering
                final mealIndex = _asInt(meal["meal_index"], fallback: idx);
                // Treat as default only if it exactly matches "Meal {index}" for this slot
                final lowerTitle = backendTitle.toLowerCase().trim();
                final isDefaultTitle =
                    backendTitle.isEmpty ||
                    lowerTitle == "meal $mealIndex" ||
                    lowerTitle ==
                        "${t.translate("diet_meal").toLowerCase()} $mealIndex";
                final displayTitle =
                    (!isDefaultTitle && backendTitle.isNotEmpty)
                    ? backendTitle
                    : "${t.translate("diet_meal")} $idx";
                final itemList = _mealItems(meal);
                final sums = _mealTotals(meal);
                final mealId = _asInt(meal["meal_id"], fallback: 0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: TaqaUiScale.radius(15),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                                  fontSize: TaqaUiScale.sp(8),
                                  fontWeight: FontWeight.w400,
                                  height: 10 / 8,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(0, -TaqaUiScale.h(11)),
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                color: TaqaUiColors.white,
                                surfaceTintColor: TaqaUiColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: TaqaUiScale.radius(10),
                                  side: BorderSide(
                                    color: TaqaUiColors.unnamedColor1c1d17
                                        .withValues(alpha: 0.10),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.more_vert,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                  size: TaqaUiScale.sp(18),
                                ),
                                onSelected: (value) async {
                                  final userId =
                                      await AccountStorage.getUserId();
                                  if (userId == null) return;
                                  final trainingDayId = _modeIndex == 1
                                      ? _asInt(
                                          _selectedTrainingDay?["day_id"],
                                          fallback: 0,
                                        )
                                      : null;
                                  if (value == 'favorites_log') {
                                    await _openFavoritesSheet(
                                      userId: userId,
                                      mealId: mealId,
                                      mealTitle: displayTitle,
                                      trainingDayId: trainingDayId,
                                    );
                                    return;
                                  }
                                  if (value == 'favorites_save') {
                                    await _saveMealAsFavorite(
                                      userId: userId,
                                      meal: meal,
                                      mealTitle: displayTitle,
                                      trainingDayId: trainingDayId,
                                    );
                                    return;
                                  }
                                  if (value == 'meal_rename') {
                                    await _renameMeal(
                                      mealId: mealId,
                                      currentTitle: displayTitle,
                                      trainingDayId: trainingDayId,
                                    );
                                    return;
                                  }
                                  if (value == 'meal_clear_items') {
                                    await _clearMealItems(
                                      items: itemList,
                                      mealTitle: displayTitle,
                                    );
                                    return;
                                  }
                                  if (value == 'meal_delete') {
                                    if (mealId <= 0) return;
                                    await _deleteMeal(
                                      mealId: mealId,
                                      mealTitle: displayTitle,
                                      items: itemList,
                                      trainingDayId: trainingDayId,
                                    );
                                  }
                                },
                                itemBuilder: (ctx) {
                                  TextStyle menuItemStyle({Color? color}) =>
                                      TextStyle(
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: TaqaUiScale.sp(13),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0,
                                        color:
                                            color ??
                                            TaqaUiColors.unnamedColor1c1d17,
                                      );
                                  return [
                                    PopupMenuItem(
                                      value: 'favorites_log',
                                      child: Text(
                                        t.translate("diet_favorites_add_from"),
                                        style: menuItemStyle(),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'favorites_save',
                                      enabled: itemList.isNotEmpty,
                                      child: Text(
                                        t.translate(
                                          "diet_favorites_save_current",
                                        ),
                                        style: menuItemStyle(),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'meal_rename',
                                      child: Text(
                                        t.translate("diet_rename_meal"),
                                        style: menuItemStyle(),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'meal_clear_items',
                                      enabled: itemList.isNotEmpty,
                                      child: Text(
                                        t.translate("diet_clear_meal_items"),
                                        style: menuItemStyle(),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'meal_delete',
                                      child: Text(
                                        t.translate("diet_delete_meal"),
                                        style: menuItemStyle(
                                          color: AppColors.errorRed,
                                        ),
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ),
                            SizedBox(width: TaqaUiScale.w(6)),
                            GestureDetector(
                              onTap: mealId <= 0
                                  ? null
                                  : () async {
                                      final userId =
                                          await AccountStorage.getUserId();
                                      if (userId == null) return;
                                      if (!context.mounted) return;

                                      final trainingDayId = _modeIndex == 1
                                          ? _asInt(
                                              _selectedTrainingDay?["day_id"],
                                              fallback: 0,
                                            )
                                          : null;

                                      // Show options first
                                      await showDialog<void>(
                                        context: context,
                                        barrierColor: const Color(0x66000000),
                                        builder: (_) => DietLoggingOptionsSheet(
                                          mealTitle: displayTitle,
                                          onSearch: () async {
                                            if (!context.mounted) return;
                                            if (_itemSearchSheetOpen) return;
                                            _itemSearchSheetOpen = true;
                                            await showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  TaqaUiColors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(
                                                        TaqaUiScale.r(15),
                                                      ),
                                                    ),
                                              ),
                                              builder: (_) => DietItemSearchSheet(
                                                rootContext: context,
                                                userId: userId,
                                                mealId: mealId,
                                                mealTitle: displayTitle,
                                                trainingDayId: trainingDayId,
                                                initialTab: 0,
                                                onLogged: (daySummary) async {
                                                  try {
                                                    if (daySummary != null &&
                                                        _meals != null &&
                                                        mounted) {
                                                      setState(() {
                                                        _meals = {
                                                          ..._meals!,
                                                          "day_summary":
                                                              daySummary,
                                                        };
                                                      });
                                                    }
                                                    if (mounted)
                                                      await _loadMeals();
                                                  } catch (_) {
                                                    if (mounted)
                                                      await _loadMeals();
                                                  }
                                                },
                                              ),
                                            );
                                            _itemSearchSheetOpen = false;
                                          },
                                          onManualEntry: () async {
                                            if (!context.mounted) return;
                                            if (_manualEntrySheetOpen) return;
                                            _manualEntrySheetOpen = true;
                                            await showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: TaqaUiColors
                                                  .unnamedColorE3e3e3,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(
                                                        TaqaUiScale.r(15),
                                                      ),
                                                    ),
                                              ),
                                              builder: (_) =>
                                                  DietManualEntrySheet(
                                                    rootContext: context,
                                                    userId: userId,
                                                    mealId: mealId,
                                                    mealTitle: displayTitle,
                                                    trainingDayId:
                                                        trainingDayId,
                                                    onLogged: (daySummary) async {
                                                      try {
                                                        if (daySummary !=
                                                                null &&
                                                            _meals != null &&
                                                            mounted) {
                                                          setState(() {
                                                            _meals = {
                                                              ..._meals!,
                                                              "day_summary":
                                                                  daySummary,
                                                            };
                                                          });
                                                        }
                                                        if (mounted)
                                                          await _loadMeals();
                                                      } catch (_) {
                                                        if (mounted)
                                                          await _loadMeals();
                                                      }
                                                    },
                                                  ),
                                            );
                                            _manualEntrySheetOpen = false;
                                          },
                                          onPhotoEntry: () async {
                                            if (!context.mounted) return;
                                            if (_photoEntrySheetOpen) return;
                                            _photoEntrySheetOpen = true;
                                            await showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: TaqaUiColors
                                                  .unnamedColorE3e3e3,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(
                                                        TaqaUiScale.r(15),
                                                      ),
                                                    ),
                                              ),
                                              builder: (_) => DietPhotoEntrySheet(
                                                rootContext: context,
                                                userId: userId,
                                                mealId: mealId,
                                                mealTitle: displayTitle,
                                                trainingDayId: trainingDayId,
                                                onLogged: (daySummary) async {
                                                  try {
                                                    if (daySummary != null &&
                                                        _meals != null &&
                                                        mounted) {
                                                      setState(() {
                                                        _meals = {
                                                          ..._meals!,
                                                          "day_summary":
                                                              daySummary,
                                                        };
                                                      });
                                                    }
                                                    if (mounted)
                                                      await _loadMeals();
                                                  } catch (_) {
                                                    if (mounted)
                                                      await _loadMeals();
                                                  }
                                                },
                                              ),
                                            );
                                            _photoEntrySheetOpen = false;
                                          },
                                        ),
                                      );
                                    },
                              child: Container(
                                padding: TaqaUiScale.insetsLTRB(8, 5, 8, 5),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                    width: 0.5,
                                  ),
                                  borderRadius: TaqaUiScale.radius(5),
                                ),
                                child: Text(
                                  "+ ${t.translate("diet_add_item_tag").toUpperCase()}",
                                  style: TextStyle(
                                    fontFamily:
                                        TaqaUiFontFamilies.iaWriterMonoS,
                                    fontSize: TaqaUiScale.sp(8),
                                    fontWeight: FontWeight.w400,
                                    height: 10 / 8,
                                    letterSpacing: 0,
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(8)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _mealMacroPair(
                              value: sums["calories"] ?? 0,
                              unit: t.translate("diet_kcal_unit"),
                              label: t.translate("diet_manual_calories"),
                              gap: 14,
                            ),
                            SizedBox(width: TaqaUiScale.w(40)),
                            _mealMacroPair(
                              value: sums["protein_g"] ?? 0,
                              unit: t.translate("diet_grams_unit"),
                              label: t.translate("protein"),
                              gap: 15,
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(12)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _mealMacroPair(
                              value: sums["carbs_g"] ?? 0,
                              unit: t.translate("diet_grams_unit"),
                              label: t.translate("diet_carbs"),
                              gap: 14,
                            ),
                            SizedBox(width: TaqaUiScale.w(40)),
                            _mealMacroPair(
                              value: sums["fat_g"] ?? 0,
                              unit: t.translate("diet_grams_unit"),
                              label: t.translate("diet_fat"),
                              gap: 15,
                            ),
                          ],
                        ),
                        if (itemList.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: itemList.map((item) {
                              final itemName = _asString(item["item_name"]);
                              final kcal = _asInt(item["calories"]);
                              final p = _asInt(item["protein_g"]);
                              final c = _asInt(item["carbs_g"]);
                              final f = _asInt(item["fat_g"]);
                              final grams = item["grams"];
                              final itemId = _mealItemId(item);
                              final ingredients = item["ingredients"];
                              final ingList = ingredients is List
                                  ? ingredients
                                        .whereType<Map>()
                                        .map((e) => e.cast<String, dynamic>())
                                        .toList()
                                  : <Map<String, dynamic>>[];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: TaqaUiColors.unnamedColorE3e3e3,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: TaqaUiColors.unnamedColor1c1d17
                                        .withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            itemName,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: TaqaUiColors
                                                      .unnamedColor1c1d17,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        if (itemId > 0)
                                          IconButton(
                                            tooltip: t.translate(
                                              "diet_add_ingredient",
                                            ),
                                            onPressed: () =>
                                                _openAddIngredientDialog(
                                                  mealItemId: itemId,
                                                  itemName: itemName,
                                                ),
                                            icon: Icon(
                                              Icons.add,
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17
                                                  .withValues(alpha: 0.6),
                                              size: 20,
                                            ),
                                          ),
                                        if (itemId > 0)
                                          IconButton(
                                            tooltip: t.translate(
                                              "diet_delete_item",
                                            ),
                                            onPressed: () => _deleteMealItem(
                                              mealItemId: itemId,
                                              itemName: itemName,
                                            ),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17
                                                  .withValues(alpha: 0.5),
                                              size: 20,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${t.translate("diet_kcal_label")} $kcal • "
                                      "${t.translate("diet_p_short")} $p • "
                                      "${t.translate("diet_c_short")} $c • "
                                      "${t.translate("diet_f_short")} $f"
                                      "${grams != null ? " • ${grams}g" : ""}",
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: TaqaUiColors
                                                .unnamedColor1c1d17
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                    if (ingList.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        ingList
                                            .map((ing) {
                                              final n = _asString(
                                                ing["ingredient_name"],
                                              );
                                              final amt = ing["amount"];
                                              final unit = _asString(
                                                ing["unit"],
                                              );
                                              final amountLabel = amt != null
                                                  ? " ${amt.toString()}"
                                                  : "";
                                              final unitLabel = unit.isNotEmpty
                                                  ? " $unit"
                                                  : "";
                                              return "$n$amountLabel$unitLabel";
                                            })
                                            .where((e) => e.trim().isNotEmpty)
                                            .join(" • "),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17
                                                  .withValues(alpha: 0.5),
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
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
          onChanged: _trainDayLockedByExercise
              ? null
              : (v) async {
                  if (v == null) return;
                  setState(() => _selectedTrainingDayIndex = v);
                  // If user is on training mode, persist calendar mapping for today.
                  if (_modeIndex == 1) {
                    try {
                      final userId = await AccountStorage.getUserId();
                      if (userId != null) {
                        final tdId = _asInt(
                          _selectedTrainingDay?["day_id"],
                          fallback: 0,
                        );
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
    final target = (live?["target"] is Map)
        ? (live?["target"] as Map).cast<String, dynamic>()
        : null;
    final consumed = (live?["consumed"] is Map)
        ? (live?["consumed"] as Map).cast<String, dynamic>()
        : null;
    final remaining = (live?["remaining"] is Map)
        ? (live?["remaining"] as Map).cast<String, dynamic>()
        : null;

    final remCal = _dsInt(remaining, "calories");
    final tarCal = _dsInt(target, "calories");
    final conCal = _dsInt(consumed, "calories");

    final frozen = _daySummarySnapshot != null;

    return Container(
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
                  t.translate("diet_remaining_title"),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (frozen)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.successGreen.withValues(alpha: 0.25),
                    ),
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
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
                  : Text(
                      frozen
                          ? t.translate("diet_day_already_frozen")
                          : t.translate("diet_freeze_day"),
                    ),
            ),
          ),
          if (!frozen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.translate("diet_freeze_note"),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ),
          if (frozen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.translate("diet_frozen_note"),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditDietTargetsResult {
  const _EditDietTargetsResult({
    required this.restCalories,
    required this.restProtein,
    required this.restCarbs,
    required this.restFat,
    required this.trainingDays,
  });

  final int restCalories;
  final int restProtein;
  final int restCarbs;
  final int restFat;

  /// Each entry: {"day_id": int, "calories": int, "protein_g": int, "carbs_g": int, "fat_g": int}
  final List<Map<String, dynamic>> trainingDays;
}

class _EditDietTargetsPage extends StatefulWidget {
  const _EditDietTargetsPage({
    required this.restCalories,
    required this.restProtein,
    required this.restCarbs,
    required this.restFat,
    required this.trainingDays,
  });

  final int restCalories;
  final int restProtein;
  final int restCarbs;
  final int restFat;
  final List<Map<String, dynamic>> trainingDays;

  @override
  State<_EditDietTargetsPage> createState() => _EditDietTargetsPageState();
}

class _EditDietTargetsPageState extends State<_EditDietTargetsPage> {
  late int _tab;
  late int _restCalories;
  late int _restProtein;
  late int _restCarbs;
  late int _restFat;
  late List<Map<String, dynamic>> _trainingValues;

  @override
  void initState() {
    super.initState();
    _tab = 0;
    _restCalories = widget.restCalories;
    _restProtein = widget.restProtein;
    _restCarbs = widget.restCarbs;
    _restFat = widget.restFat;
    _trainingValues = widget.trainingDays
        .map(
          (d) => {
            "day_id": d["day_id"],
            "day_label": d["day_label"],
            "calories": DietPageState._asInt(d["train_calories"]),
            "protein_g": DietPageState._asInt(d["train_protein_g"]),
            "carbs_g": DietPageState._asInt(d["train_carbs_g"]),
            "fat_g": DietPageState._asInt(d["train_fat_g"]),
          },
        )
        .toList();
  }

  String _dayLabelFor(AppLocalizations t, int index) {
    final d = widget.trainingDays[index];
    final label = DietPageState._asString(d["day_label"]);
    final dayId = DietPageState._asInt(d["day_id"], fallback: index + 1);
    return label.isNotEmpty ? label : "${t.translate("diet_day")} $dayId";
  }

  Widget _buildTab(String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: TaqaUiScale.h(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? TaqaUiColors.unnamedColorE4e93b : TaqaUiColors.white,
          borderRadius: TaqaUiScale.radius(5),
          border: active
              ? null
              : Border.all(
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(
                    alpha: 0.12,
                  ),
                ),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w600,
            color: onTap == null
                ? TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35)
                : TaqaUiColors.unnamedColor1c1d17,
            height: 12 / 10,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _nutrientCell(
    String label,
    int value,
    String unit,
    ValueChanged<int> onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final result = await showTaqaValueDialog(
          context: context,
          title: label,
          initialValue: value > 0 ? "$value" : "",
        );
        if (result != null) onChanged(result);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.unnamedColor1c1d17,
              height: 12 / 10,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(5)),
          Text(
            "$value $unit",
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColorE3e3e3,
              height: 21 / 15,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientsCard(
    AppLocalizations t, {
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required void Function(String key, int value) onChanged,
  }) {
    final kcalUnit = t.translate("diet_kcal_unit");
    final gUnit = t.translate("diet_grams_unit");
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(15, 15, 15, 15),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _nutrientCell(
                  t.translate("diet_manual_calories"),
                  calories,
                  kcalUnit,
                  (v) => onChanged("calories", v),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(15)),
              Expanded(
                child: _nutrientCell(
                  t.translate("protein"),
                  protein,
                  gUnit,
                  (v) => onChanged("protein_g", v),
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: TaqaUiColors.unnamedColorE3e3e3,
                ),
              ),
              SizedBox(width: TaqaUiScale.w(15)),
              Expanded(
                child: Container(
                  height: 1,
                  color: TaqaUiColors.unnamedColorE3e3e3,
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _nutrientCell(
                  t.translate("diet_carbs"),
                  carbs,
                  gUnit,
                  (v) => onChanged("carbs_g", v),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(15)),
              Expanded(
                child: _nutrientCell(
                  t.translate("diet_fat"),
                  fat,
                  gUnit,
                  (v) => onChanged("fat_g", v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop(
      _EditDietTargetsResult(
        restCalories: _restCalories,
        restProtein: _restProtein,
        restCarbs: _restCarbs,
        restFat: _restFat,
        trainingDays: _trainingValues,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasTrainingDays = widget.trainingDays.isNotEmpty;
    final dayLabelStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(15),
      fontWeight: FontWeight.w700,
      color: TaqaUiColors.unnamedColor1c1d17,
      height: 25 / 15,
      letterSpacing: 0,
    );

    return Scaffold(
      backgroundColor: TaqaUiColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: TaqaUiScale.insetsLTRB(8, 8, 8, 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      size: TaqaUiScale.sp(20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      t.translate("diet_edit_targets"),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.unnamedColor1c1d17,
                        height: 25 / 15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(48)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: TaqaUiScale.insetsLTRB(16, 20, 17, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTab(
                            t.translate("diet_rest_day"),
                            _tab == 0,
                            () => setState(() => _tab = 0),
                          ),
                        ),
                        SizedBox(width: TaqaUiScale.w(15)),
                        Expanded(
                          child: _buildTab(
                            t.translate("diet_training_day"),
                            _tab == 1,
                            hasTrainingDays
                                ? () => setState(() => _tab = 1)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: TaqaUiScale.h(15)),
                    if (_tab == 0) ...[
                      Text(t.translate("diet_rest_day"), style: dayLabelStyle),
                      SizedBox(height: TaqaUiScale.h(10)),
                      _buildNutrientsCard(
                        t,
                        calories: _restCalories,
                        protein: _restProtein,
                        carbs: _restCarbs,
                        fat: _restFat,
                        onChanged: (key, value) {
                          setState(() {
                            switch (key) {
                              case "calories":
                                _restCalories = value;
                                break;
                              case "protein_g":
                                _restProtein = value;
                                break;
                              case "carbs_g":
                                _restCarbs = value;
                                break;
                              case "fat_g":
                                _restFat = value;
                                break;
                            }
                          });
                        },
                      ),
                    ] else if (hasTrainingDays)
                      for (var i = 0; i < widget.trainingDays.length; i++) ...[
                        if (i > 0) SizedBox(height: TaqaUiScale.h(24)),
                        Text(_dayLabelFor(t, i), style: dayLabelStyle),
                        SizedBox(height: TaqaUiScale.h(10)),
                        _buildNutrientsCard(
                          t,
                          calories: _trainingValues[i]["calories"] as int,
                          protein: _trainingValues[i]["protein_g"] as int,
                          carbs: _trainingValues[i]["carbs_g"] as int,
                          fat: _trainingValues[i]["fat_g"] as int,
                          onChanged: (key, value) {
                            setState(() {
                              _trainingValues[i][key] = value;
                            });
                          },
                        ),
                      ]
                    else
                      Text(
                        t.translate("diet_training_day_targets_unavailable"),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(13),
                          fontWeight: FontWeight.w400,
                          color: TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: TaqaUiScale.insetsLTRB(16, 12, 17, 24),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        height: TaqaUiScale.h(45),
                        alignment: Alignment.center,
                        child: Text(
                          t.translate("diet_edit_targets_cancel").toUpperCase(),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(10),
                            fontWeight: FontWeight.w600,
                            color: TaqaUiColors.unnamedColor1c1d17,
                            height: 12 / 10,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(15)),
                  Expanded(
                    child: GestureDetector(
                      onTap: _save,
                      child: Container(
                        height: TaqaUiScale.h(45),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TaqaUiColors.unnamedColor1c1d17,
                          borderRadius: TaqaUiScale.radius(5),
                        ),
                        child: Text(
                          t.translate("diet_edit_targets_save").toUpperCase(),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(10),
                            fontWeight: FontWeight.w700,
                            color: TaqaUiColors.white,
                            height: 12 / 10,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
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
