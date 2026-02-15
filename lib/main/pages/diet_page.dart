import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';
import '../../core/account_storage.dart';
import '../../core/diet_regeneration_flag.dart';
import '../../localization/app_localizations.dart';
import '../../services/diet/diet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/diet_item_search_sheet.dart';
import '../../widgets/diet_logging_options_sheet.dart';
import '../../widgets/diet_manual_entry_sheet.dart';
import '../../widgets/diet_photo_entry_sheet.dart';
import '../../widgets/diet_favorites_sheet.dart';
import '../../services/training/training_completion_storage.dart';
import '../../services/training/training_calendar_service.dart';

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
  /// When diet is generating in background, we poll until targets appear.
  Timer? _targetsPollTimer;

  bool _mealsLoading = true;
  String? _mealsError;
  Map<String, dynamic>? _meals;
  final DateTime _mealDate = DateTime.now();
  bool _mealsFromCache = false;
  bool _freezing = false;
  int _mealsRequestId = 0;
  bool _manualMealDialogOpen = false;
  bool _itemSearchSheetOpen = false;
  bool _manualEntrySheetOpen = false;
  bool _photoEntrySheetOpen = false;

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

  @override
  void dispose() {
    _targetsPollTimer?.cancel();
    _targetsPollTimer = null;
    super.dispose();
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
    if (didComplete) _loadMeals(clearExisting: true);
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
      // While diet was just regenerated (e.g. after training days change), don't
      // accept the first response — it may still be old. Wait and keep polling.
      if (DietRegenerationFlag.isRegenerating && !DietRegenerationFlag.canAcceptTargets) {
        _targetsPollTimer?.cancel();
        _targetsPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted) return;
          _loadTargets(forceNetwork: true);
        });
        setState(() {
          _loading = true;
          _error = null;
          _targetsFromCache = false;
        });
        return;
      }
      DietRegenerationFlag.clear();
      _targetsPollTimer?.cancel();
      _targetsPollTimer = null;
      setState(() {
        _targets = data;
        _loading = false;
        _error = null;
        _targetsFromCache = false;
        _selectedTrainingDayIndex = 0;
      });
    } catch (e) {
      // Cache fallback (offline-friendly) — but never show old cache while diet is regenerating
      if (!DietRegenerationFlag.isRegenerating) {
        try {
          final cached = await DietService.fetchCurrentTargetsFromCache();
          if (!mounted) return;
          if (cached != null) {
            _targetsPollTimer?.cancel();
            _targetsPollTimer = null;
            setState(() {
              _targets = cached;
              _loading = false;
              _error = null;
              _targetsFromCache = true;
              _selectedTrainingDayIndex = 0;
            });
            return;
          }
        } catch (_) {
          // ignore cache load errors
        }
      }

      // Diet still generating in background: keep loading and poll until ready
      if (!mounted) return;
      _targetsPollTimer?.cancel();
      _targetsPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        _loadTargets(forceNetwork: true);
      });
      setState(() {
        _loading = true;
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

  static String _dateLabel(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  Future<void> _loadMeals({bool clearExisting = false}) async {
    _mealsRequestId++;
    final requestId = _mealsRequestId;
    setState(() {
      _mealsLoading = true;
      _mealsError = null;
      _mealsFromCache = false;
      if (clearExisting) {
        _meals = null; // avoid showing stale summary/macros during mode switch
      }
    });

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        throw Exception("User not found");
      }

      // When in training mode, fetch meals for that training day so create/fetch match
      final trainingDayId = _modeIndex == 1
          ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
          : null;
      final effectiveTdId = (trainingDayId != null && trainingDayId > 0) ? trainingDayId : null;

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
        final effectiveTdId = (trainingDayId != null && trainingDayId > 0) ? trainingDayId : null;
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

  List<Map<String, dynamic>> _mealItems(Map<String, dynamic> meal) {
    final list = meal["items"];
    if (list is List) {
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  int _mealItemId(Map<String, dynamic> item) {
    // Backend likely uses "id" for meal item primary key; fall back to other keys if present.
    return _asInt(item["meal_item_id"] ?? item["id"] ?? item["item_id"], fallback: 0);
  }

  int _dsInt(Map<String, dynamic>? m, String key) => _asInt(m?[key], fallback: 0);

  Future<void> _openAddIngredientDialog({
    required int mealItemId,
    required String itemName,
  }) async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final res = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            scrollable: true,
            title: Text(t.translate("diet_add_ingredient")),
            content: Form(
              key: formKey,
              child: Column(
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: t.translate("diet_ingredient_name"),
                    ),
                    validator: (v) {
                      final trimmed = v?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return t.translate("diet_ingredient_name_required");
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: t.translate("diet_ingredient_amount"),
                      hintText: t.translate("diet_ingredient_optional"),
                    ),
                    validator: (v) {
                      final trimmed = v?.trim() ?? '';
                      if (trimmed.isEmpty) return null;
                      final val = double.tryParse(trimmed);
                      if (val == null || val <= 0) {
                        return t.translate("diet_ingredient_amount_invalid");
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: unitCtrl,
                    decoration: InputDecoration(
                      labelText: t.translate("diet_ingredient_unit"),
                      hintText: t.translate("diet_ingredient_optional"),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(t.translate("common_cancel")),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(ctx).pop(true);
                },
                child: Text(t.translate("diet_add_ingredient")),
              ),
            ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_ingredient_added"))),
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("diet_ingredient_add_failed")}: $e")),
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
      backgroundColor: AppColors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
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
  }

  Future<void> _saveMealAsFavorite({
    required int userId,
    required Map<String, dynamic> meal,
    required String mealTitle,
  }) async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: mealTitle);
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: Text(t.translate("diet_favorites_save_title")),
          content: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: t.translate("diet_favorites_name"),
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return t.translate("diet_favorites_name_required");
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: t.translate("diet_favorites_notes"),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop(true);
              },
              child: Text(t.translate("diet_favorites_save")),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final items = _mealItems(meal);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_favorites_empty_meal"))),
      );
      return;
    }

    final payloadItems = items.asMap().entries.map((entry) {
      final index = entry.key; // 0-based
      final item = entry.value;
      final ingredients = item['ingredients'];
      final ingList = ingredients is List
          ? ingredients.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
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
      await DietService.createFavoriteMeal(
        userId: userId,
        mealName: nameCtrl.text.trim(),
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        items: payloadItems,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_favorites_saved"))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("diet_favorites_save_failed")}: $e")),
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
    final titleCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            scrollable: true,
            title: Text(t.translate("diet_add_meal_title")),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: t.translate("diet_add_meal_name"),
                  hintText: t.translate("diet_add_meal_name_hint"),
                ),
                validator: (v) {
                  final trimmed = v?.trim() ?? '';
                  if (trimmed.length > 120) {
                    return t.translate("diet_add_meal_name_too_long");
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(t.translate("common_cancel")),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(ctx).pop(true);
                },
                child: Text(t.translate("diet_add_meal_confirm")),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;

      final userId = await AccountStorage.getUserId();
      if (userId == null) return;

      final trainingDayId = _modeIndex == 1
          ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
          : null;
      final effectiveTdId = (trainingDayId != null && trainingDayId > 0) ? trainingDayId : null;

      final created = await DietService.createMeal(
        userId: userId,
        date: _mealDate,
        title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
        trainingDayId: effectiveTdId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_add_meal_success"))),
      );

      // Optimistically add the new meal so it appears immediately
      final mealData = created["meal"] is Map
          ? Map<String, dynamic>.from(created["meal"] as Map)
          : created;
      final mealId = _asInt(mealData["meal_id"], fallback: _asInt(mealData["id"], fallback: 0));
      final newMeal = mealId > 0
          ? <String, dynamic>{
              "meal_id": mealId,
              "title": mealData["title"] ?? titleCtrl.text.trim(),
              "items": mealData["items"] ?? mealData["meal_items"] ?? [],
            }
          : null;
      if (newMeal != null) {
        setState(() {
          if (_meals != null) {
            final mealsList = _meals!["meals"];
            if (mealsList is List) {
              final updated = List<Map<String, dynamic>>.from(
                mealsList.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
              );
              updated.add(newMeal);
              _meals = Map<String, dynamic>.from(_meals!);
              _meals!["meals"] = updated;
            }
          } else {
            _meals = {"meals": [newMeal]};
          }
        });
      }

      await _loadMeals();
      // If the backend didn't return the new meal (e.g. caps at meals_per_day), keep it in the list
      if (!mounted || newMeal == null) return;
      final list = _meals?["meals"];
      if (list is List) {
        final hasNew = list.any((m) =>
            _asInt(m is Map ? m["meal_id"] : null, fallback: 0) == mealId ||
            _asInt(m is Map ? m["id"] : null, fallback: 0) == mealId);
        if (!hasNew) {
          setState(() {
            _meals = Map<String, dynamic>.from(_meals!);
            _meals!["meals"] = List<Map<String, dynamic>>.from(
              list.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
            )..add(newMeal);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("diet_add_meal_failed")}: $e")),
      );
    } finally {
      _manualMealDialogOpen = false;
      // Dispose after the dialog route has fully settled to avoid disposing
      // a controller still attached during transition.
      final ctrl = titleCtrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.dispose();
      });
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: Text(t.translate("diet_delete_meal_title")),
          content: Text(
            "${(itemCount > 0 ? t.translate("diet_delete_meal_confirm_has_items") : t.translate("diet_delete_meal_confirm_empty")).replaceAll("{meal}", mealTitle)}\n\n${t.translate("diet_delete_meal_note")}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.translate("diet_delete_meal_confirm")),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_delete_meal_success"))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("diet_delete_meal_failed")}: $e")),
      );
    }
  }

  Future<void> _deleteMealItem({
    required int mealItemId,
    required String itemName,
  }) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: Text(t.translate("diet_delete_item_title")),
          content: Text(
            t.translate("diet_delete_item_confirm").replaceAll("{item}", itemName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.translate("diet_delete_item_confirm_button")),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      await DietService.deleteMealItem(userId: userId, mealItemId: mealItemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_delete_item_success"))),
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("diet_delete_item_failed")}: $e")),
      );
    }
  }

  Future<void> _clearMealItems({
    required List<Map<String, dynamic>> items,
    required String mealTitle,
  }) async {
    final t = AppLocalizations.of(context);
    if (items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: Text(t.translate("diet_clear_meal_title")),
          content: Text(
            t.translate("diet_clear_meal_confirm").replaceAll("{meal}", mealTitle),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.translate("diet_clear_meal_confirm_button")),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      for (final item in items) {
        final itemId = _mealItemId(item);
        if (itemId <= 0) continue;
        await DietService.deleteMealItem(userId: userId, mealItemId: itemId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("diet_clear_meal_success"))),
      );
      await _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("diet_clear_meal_failed")}: $e")),
      );
    }
  }

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

                if (_loading || _targets == null || DietRegenerationFlag.isRegenerating) ...[
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
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
                          _loadMeals(clearExisting: true);
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
                    _buildTrainingDayPicker(
                      theme,
                      onChanged: () => _loadMeals(clearExisting: true),
                    ),
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
                    IconButton(
                      tooltip: t.translate("diet_add_meal_title"),
                      onPressed: _mealsLoading ? null : _createMealManually,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
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
                  ..._mealList.asMap().entries.map((entry) {
                    final listIndex = entry.key;
                    final meal = entry.value;
                    final backendTitle = _asString(meal["title"]);
                    final idx = listIndex + 1; // Frontend display index (1..N) - always use this for numbering
                    // Use custom title only if it's not a default "Meal X" pattern
                    final isDefaultTitle = backendTitle.isEmpty || 
                        RegExp(r'^Meal\s+\d+$', caseSensitive: false).hasMatch(backendTitle) ||
                        RegExp(r'^' + t.translate("diet_meal") + r'\s+\d+$', caseSensitive: false).hasMatch(backendTitle);
                    final displayTitle = (!isDefaultTitle && backendTitle.isNotEmpty) 
                        ? backendTitle 
                        : "${t.translate("diet_meal")} $idx";
                    final itemList = _mealItems(meal);
                    final items = itemList.length;
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
                                    displayTitle,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                                  onSelected: (value) async {
                                    final userId = await AccountStorage.getUserId();
                                    if (userId == null) return;
                                    final trainingDayId = _modeIndex == 1
                                        ? _asInt(_selectedTrainingDay?["day_id"], fallback: 0)
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
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'favorites_log',
                                      child: Text(t.translate("diet_favorites_add_from")),
                                    ),
                                    PopupMenuItem(
                                      value: 'favorites_save',
                                      enabled: itemList.isNotEmpty,
                                      child: Text(t.translate("diet_favorites_save_current")),
                                    ),
                                    PopupMenuItem(
                                      value: 'meal_clear_items',
                                      enabled: itemList.isNotEmpty,
                                      child: Text(t.translate("diet_clear_meal_items")),
                                    ),
                                    PopupMenuItem(
                                      value: 'meal_delete',
                                      child: Text(t.translate("diet_delete_meal")),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  tooltip: t.translate("diet_add_item"),
                                  onPressed: mealId <= 0
                                      ? null
                                      : () async {
                                          final userId = await AccountStorage.getUserId();
                                          if (userId == null) return;
                                          if (!context.mounted) return;

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
                                              mealTitle: displayTitle,
                                              onSearch: () async {
                                                if (!context.mounted) return;
                                                if (_itemSearchSheetOpen) return;
                                                _itemSearchSheetOpen = true;
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
                                                    mealTitle: displayTitle,
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
                                                _itemSearchSheetOpen = false;
                                              },
                                              onManualEntry: () async {
                                                if (!context.mounted) return;
                                                if (_manualEntrySheetOpen) return;
                                                _manualEntrySheetOpen = true;
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
                                                    mealTitle: displayTitle,
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
                                                _manualEntrySheetOpen = false;
                                              },
                                              onPhotoEntry: () async {
                                                if (!context.mounted) return;
                                                if (_photoEntrySheetOpen) return;
                                                _photoEntrySheetOpen = true;
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
                                                    mealTitle: displayTitle,
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
                                                _photoEntrySheetOpen = false;
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
                                      ? ingredients.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
                                      : <Map<String, dynamic>>[];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
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
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (itemId > 0)
                                              IconButton(
                                                tooltip: t.translate("diet_add_ingredient"),
                                                onPressed: () => _openAddIngredientDialog(
                                                  mealItemId: itemId,
                                                  itemName: itemName,
                                                ),
                                                icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                                              ),
                                            if (itemId > 0)
                                              IconButton(
                                                tooltip: t.translate("diet_delete_item"),
                                                onPressed: () => _deleteMealItem(
                                                  mealItemId: itemId,
                                                  itemName: itemName,
                                                ),
                                                icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
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
                                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                                        ),
                                        if (ingList.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            ingList
                                                .map((ing) {
                                                  final n = _asString(ing["ingredient_name"]);
                                                  final amt = ing["amount"];
                                                  final unit = _asString(ing["unit"]);
                                                  final amountLabel = amt != null ? " ${amt.toString()}" : "";
                                                  final unitLabel = unit.isNotEmpty ? " $unit" : "";
                                                  return "$n$amountLabel$unitLabel";
                                                })
                                                .where((e) => e.trim().isNotEmpty)
                                                .join(" • "),
                                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
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
