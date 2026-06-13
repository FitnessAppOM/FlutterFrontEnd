import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../services/diet/nutrition_search_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_steps_ui.dart' show TaqaRangeTab;
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class DietItemSearchSheet extends StatefulWidget {
  const DietItemSearchSheet({
    super.key,
    required this.rootContext,
    required this.userId,
    required this.mealId,
    required this.mealTitle,
    this.trainingDayId,
    required this.onLogged,
    this.initialTab = 0, // 0 = foods, 1 = restaurants
    this.onPickForManualEntry,
  });

  /// Use a stable parent context (Scaffold) for SnackBars.
  /// Avoids RenderObject 'attached' assertions when the sheet is closing.
  final BuildContext rootContext;
  final int userId;
  final int mealId;
  final String mealTitle;
  final int? trainingDayId;
  final Future<void> Function(Map<String, dynamic>? daySummary) onLogged;
  final int initialTab;

  /// When set, picking a result does NOT log the item to the backend.
  /// Instead the picked ingredient data is handed back via this callback
  /// (used by the manual entry sheet to add an editable ingredient row).
  final void Function(Map<String, dynamic> ingredient)? onPickForManualEntry;

  @override
  State<DietItemSearchSheet> createState() => _DietItemSearchSheetState();
}

class _DietItemSearchSheetState extends State<DietItemSearchSheet> {
  final _qCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String? _error;
  late int _tabIndex; // 0 foods, 1 restaurants
  /// Set true before popping so we never rebuild the TextField with _qCtrl after dispose.
  bool _isPopping = false;

  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
    _searchNow();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtrl.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    if (_isPopping) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _searchNow);
  }

  Future<void> _searchNow() async {
    if (_isPopping) return;
    final q = _qCtrl.text.trim();
    // Backend now accepts 1 character or empty string for foods search
    // For restaurants, searches both restaurant name and food name
    // Empty search returns all items (paginated), so we allow it

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = _tabIndex == 0
          ? await NutritionSearchService.searchFoods(q: q, limit: 25, offset: 0)
          : await NutritionSearchService.searchRestaurants(
              q: q,
              limit: 25,
              offset: 0,
            );
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _promptAndLogFood(Map<String, dynamic> item) async {
    final t = AppLocalizations.of(context);
    final foodId = int.tryParse(item['id']?.toString() ?? '');
    if (foodId == null) return;

    final grams = await _numberDialog(
      title: t.translate("diet_enter_grams_title"),
      hint: t.translate("diet_grams_hint"),
      unit: t.translate("diet_grams_unit"),
      initial: "100",
    );
    if (!mounted || grams == null) return;
    if (grams <= 0) return;

    Map<String, dynamic>? daySummary;
    await _runLogAction(() async {
      final response = await DietService.addItemFromFoodsMaster(
        userId: widget.userId,
        mealId: widget.mealId,
        foodId: foodId,
        grams: grams,
        trainingDayId: widget.trainingDayId,
      );
      daySummary = response["day_summary"] is Map
          ? (response["day_summary"] as Map).cast<String, dynamic>()
          : null;
    }, successToast: t.translate("diet_item_added"));

    if (!mounted) return;
    final onLogged = widget.onLogged;
    final summary = daySummary;
    setState(() => _isPopping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLogged(summary);
      });
    });
  }

  Future<void> _promptAndLogRestaurant(Map<String, dynamic> item) async {
    final t = AppLocalizations.of(context);
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;

    final qty = await _intDialog(
      title: t.translate("diet_enter_quantity_title"),
      hint: t.translate("diet_quantity_hint"),
      unit: t.translate("diet_quantity_unit"),
      initial: "1",
    );
    if (!mounted || qty == null) return;
    if (qty < 1) return;

    Map<String, dynamic>? daySummary;
    await _runLogAction(() async {
      final response = await DietService.addItemFromRestaurants(
        userId: widget.userId,
        mealId: widget.mealId,
        restaurantItemId: id,
        quantity: qty,
        trainingDayId: widget.trainingDayId,
      );
      daySummary = response["day_summary"] is Map
          ? (response["day_summary"] as Map).cast<String, dynamic>()
          : null;
    }, successToast: t.translate("diet_item_added"));

    if (!mounted) return;
    final onLogged = widget.onLogged;
    final summary = daySummary;
    setState(() => _isPopping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLogged(summary);
      });
    });
  }

  double _numFrom(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final v = payload[key];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final parsed = double.tryParse(v.toString().replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return 0;
  }

  /// Pick a result for the manual entry sheet instead of logging it directly.
  Future<void> _pickForManualEntry(Map<String, dynamic> item) async {
    final onPick = widget.onPickForManualEntry;
    if (onPick == null) return;
    final t = AppLocalizations.of(context);

    Map<String, dynamic>? ingredient;

    if (_tabIndex == 0) {
      final foodId = int.tryParse(item['id']?.toString() ?? '');
      if (foodId == null) return;

      final grams = await _numberDialog(
        title: t.translate("diet_enter_grams_title"),
        hint: t.translate("diet_grams_hint"),
        unit: t.translate("diet_grams_unit"),
        initial: "100",
      );
      if (!mounted || grams == null || grams <= 0) return;

      setState(() => _loading = true);
      try {
        final preview = await DietService.previewManualItemFromFoodsMaster(
          userId: widget.userId,
          foodId: foodId,
          grams: grams,
        );
        if (!mounted) return;
        final itemName = (preview['item_name'] ?? '').toString().trim();
        ingredient = {
          'name': itemName.isNotEmpty ? itemName : _foodName(item),
          'grams': grams,
          'calories': _numFrom(preview, const [
            'calories',
            'calories_kcal',
            'kcal',
          ]),
          'protein': _numFrom(preview, const ['protein_g', 'protein']),
          'carbs': _numFrom(preview, const [
            'carbs_g',
            'carbs',
            'carbohydrates_g',
            'carbohydrate_g',
          ]),
          'fat': _numFrom(preview, const [
            'fat_g',
            'fats_g',
            'fat',
            'total_fat_g',
            'total_fat',
          ]),
          'food_id': foodId,
        };
      } catch (e) {
        if (!mounted) return;
        if (widget.rootContext.mounted) {
          ScaffoldMessenger.of(widget.rootContext).showSnackBar(
            SnackBar(
              content: Text("${t.translate("diet_failed_to_add_item")}: $e"),
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      final qty = await _intDialog(
        title: t.translate("diet_enter_quantity_title"),
        hint: t.translate("diet_quantity_hint"),
        unit: t.translate("diet_quantity_unit"),
        initial: "1",
      );
      if (!mounted || qty == null || qty < 1) return;

      final restaurantSubtitle = _restaurantSubtitle(item);
      ingredient = {
        'name': restaurantSubtitle.isNotEmpty
            ? restaurantSubtitle
            : _restaurantName(item),
        'grams': null,
        'calories': _numFrom(item, const ['calories_kcal', 'calories']) * qty,
        'protein': _numFrom(item, const ['protein_g']) * qty,
        'carbs': _numFrom(item, const ['carbs_g']) * qty,
        'fat': _numFrom(item, const ['fat_g']) * qty,
        'food_id': null,
      };
    }

    if (!mounted) return;
    onPick(ingredient);
    setState(() => _isPopping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  Future<void> _runLogAction(
    Future<void> Function() action, {
    required String successToast,
  }) async {
    final t = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(
          widget.rootContext,
        ).showSnackBar(SnackBar(content: Text(successToast)));
      }
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(
            content: Text("${t.translate("diet_failed_to_add_item")}: $e"),
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<double?> _numberDialog({
    required String title,
    required String hint,
    required String unit,
    required String initial,
  }) async {
    final t = AppLocalizations.of(context);
    String value = initial;
    final res = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextFormField(
              initialValue: initial,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) => value = v,
              decoration: InputDecoration(hintText: hint, suffixText: unit),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(t.translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(value.trim());
                Navigator.of(ctx).pop(v);
              },
              child: Text(t.translate("diet_log")),
            ),
          ],
        );
      },
    );
    return res;
  }

  Future<int?> _intDialog({
    required String title,
    required String hint,
    required String unit,
    required String initial,
  }) async {
    final t = AppLocalizations.of(context);
    String value = initial;
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextFormField(
              initialValue: initial,
              keyboardType: TextInputType.number,
              onChanged: (v) => value = v,
              decoration: InputDecoration(hintText: hint, suffixText: unit),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(t.translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                final v = int.tryParse(value.trim());
                Navigator.of(ctx).pop(v);
              },
              child: Text(t.translate("diet_log")),
            ),
          ],
        );
      },
    );
    return res;
  }

  String _foodName(Map<String, dynamic> item) {
    return (item['food_name'] ?? '').toString().trim();
  }

  String _foodSubtitle(Map<String, dynamic> item) {
    return (item['category'] ?? '').toString().trim();
  }

  String _restaurantName(Map<String, dynamic> item) {
    final brand = (item['brand_or_restaurant'] ?? '').toString().trim();
    final name = (item['food_name'] ?? '').toString().trim();
    return brand.isNotEmpty ? brand : name;
  }

  String _restaurantSubtitle(Map<String, dynamic> item) {
    final brand = (item['brand_or_restaurant'] ?? '').toString().trim();
    final name = (item['food_name'] ?? '').toString().trim();
    return brand.isNotEmpty ? name : '';
  }

  String _macroSubtitle(Map<String, dynamic> item) {
    final t = AppLocalizations.of(context);
    // These are per-100g/per-serving/per-item depending on backend rows.
    final kcal = item['calories_kcal'] ?? item['calories'] ?? 0;
    final p = item['protein_g'] ?? 0;
    final c = item['carbs_g'] ?? 0;
    final f = item['fat_g'] ?? 0;
    return "${t.translate("diet_kcal_label")} $kcal • "
        "${t.translate("diet_p_short")} $p • "
        "${t.translate("diet_c_short")} $c • "
        "${t.translate("diet_f_short")} $f";
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  height: 5,
                  width: 44,
                  margin: EdgeInsets.only(bottom: TaqaUiScale.h(16)),
                  decoration: BoxDecoration(
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      t.translate("diet_add_item_title"),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.mealTitle,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _isPopping
                    ? Container(
                        height: TaqaUiScale.h(39),
                        decoration: BoxDecoration(
                          color: TaqaUiColors.white,
                          borderRadius: TaqaUiScale.radius(15),
                          border: Border.all(
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.10,
                            ),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: TaqaUiScale.symmetric(horizontal: 14),
                        child: Text(
                          "Search",
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            letterSpacing: 0,
                            color: TaqaUiColors.unnamedColorE3e3e3,
                          ),
                        ),
                      )
                    : Container(
                        height: TaqaUiScale.h(39),
                        padding: TaqaUiScale.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: TaqaUiColors.white,
                          borderRadius: TaqaUiScale.radius(15),
                          border: Border.all(
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.10,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: TaqaUiScale.w(18),
                              color: TaqaUiColors.unnamedColorE3e3e3,
                            ),
                            SizedBox(width: TaqaUiScale.w(8)),
                            Expanded(
                              child: TextField(
                                controller: _qCtrl,
                                onChanged: (_) => _scheduleSearch(),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(15),
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: "Search",
                                  hintStyle: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(15),
                                    letterSpacing: 0,
                                    color: TaqaUiColors.unnamedColorE3e3e3,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                SizedBox(height: TaqaUiScale.h(12)),
                Row(
                  children: [
                    Expanded(
                      child: TaqaRangeTab(
                        label: t.translate("diet_tab_foods"),
                        selected: _tabIndex == 0,
                        onTap: () {
                          if (_tabIndex == 0) return;
                          setState(() {
                            _tabIndex = 0;
                            _results = [];
                            _error = null;
                          });
                          _scheduleSearch();
                        },
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(15)),
                    Expanded(
                      child: TaqaRangeTab(
                        label: t.translate("diet_tab_restaurants"),
                        selected: _tabIndex == 1,
                        onTap: () {
                          if (_tabIndex == 1) return;
                          setState(() {
                            _tabIndex = 1;
                            _results = [];
                            _error = null;
                          });
                          _scheduleSearch();
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                Expanded(child: _buildResults()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final t = AppLocalizations.of(context);

    // Backend now accepts 1 character or empty string, so no minimum check needed
    // Empty search returns all items (paginated)

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          t.translate("diet_no_results"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => SizedBox(height: TaqaUiScale.h(12)),
      itemBuilder: (ctx, i) => _buildResultItem(_results[i]),
    );
  }

  Widget _buildResultItem(Map<String, dynamic> item) {
    final t = AppLocalizations.of(context);
    final name = _tabIndex == 0 ? _foodName(item) : _restaurantName(item);
    final subtitle = _tabIndex == 0
        ? _foodSubtitle(item)
        : _restaurantSubtitle(item);
    final macros = _macroSubtitle(item);
    final nameStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(15),
      fontWeight: FontWeight.w700,
      height: 21 / 15,
      letterSpacing: 0,
      color: TaqaUiColors.unnamedColor1c1d17,
    );

    return InkWell(
      borderRadius: TaqaUiScale.radius(15),
      onTap: widget.onPickForManualEntry != null
          ? () => _pickForManualEntry(item)
          : (_tabIndex == 0
                ? () => _promptAndLogFood(item)
                : () => _promptAndLogRestaurant(item)),
      child: Container(
        padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
        decoration: BoxDecoration(
          color: TaqaUiColors.white,
          borderRadius: TaqaUiScale.radius(15),
          border: Border.all(
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle.copyWith(
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(8)),
                Container(
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
                      fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                      fontSize: TaqaUiScale.sp(8),
                      fontWeight: FontWeight.w400,
                      height: 10 / 8,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            Text(
              macros,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w400,
                height: 21 / 15,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
