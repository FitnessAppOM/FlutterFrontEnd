import 'dart:async';
import 'package:flutter/material.dart';
import '../core/user_friendly_error.dart';
import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../services/diet/nutrition_search_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_steps_ui.dart' show TaqaRangeTab;
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
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
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  bool _loading = false;
  String? _error;
  late int _tabIndex; // 0 foods, 1 restaurants
  /// Set true before popping so we never rebuild the TextField with _qCtrl after dispose.
  bool _isPopping = false;

  // Pagination: fetch a page at a time, append on scroll, stop at the end.
  static const int _pageSize = 30;
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  /// Increments on every fresh search so stale in-flight pages are discarded.
  int _searchToken = 0;

  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
    _scrollCtrl.addListener(_onScroll);
    _searchNow();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // Prefetch the next page when within 300px of the bottom.
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _scheduleSearch() {
    if (_isPopping) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _searchNow);
  }

  Future<List<Map<String, dynamic>>> _fetchPage(String q, int offset) {
    return _tabIndex == 0
        ? NutritionSearchService.searchFoods(
            q: q,
            limit: _pageSize,
            offset: offset,
          )
        : NutritionSearchService.searchRestaurants(
            q: q,
            limit: _pageSize,
            offset: offset,
          );
  }

  Future<void> _searchNow() async {
    if (_isPopping) return;
    final q = _qCtrl.text.trim();
    final token = ++_searchToken;
    // Backend now accepts 1 character or empty string for foods search
    // For restaurants, searches both restaurant name and food name
    // Empty search returns all items (paginated), so we allow it

    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
      _loadingMore = false;
    });

    try {
      final items = await _fetchPage(q, 0);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = items;
        _offset = items.length;
        _hasMore = items.length >= _pageSize;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _loading = false;
        _error = userFriendlyErrorMessage(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isPopping || _loadingMore || _loading || !_hasMore) return;
    final q = _qCtrl.text.trim();
    final token = _searchToken;
    setState(() => _loadingMore = true);
    try {
      final items = await _fetchPage(q, _offset);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = [..._results, ...items];
        _offset += items.length;
        _hasMore = items.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      // Keep existing results; just stop the spinner and allow retry on scroll.
      setState(() => _loadingMore = false);
    }
  }

  // --- Portion variants (per-100g "weight" vs per-serving) ------------------
  // Search results collapse a food's portion variants into one row and carry
  // them in item['variants']. When a food has BOTH a weight (per_100g) and a
  // serving variant we let the user choose; otherwise we go straight to
  // whichever the food actually has.

  List<Map<String, dynamic>> _variantsOf(Map<String, dynamic> item) {
    final raw = item['variants'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    // Fallback (single-variant / older payloads): treat the row itself as one.
    return [
      {
        'id': item['id'],
        'portion_type': item['portion_type'],
        'serving_size_qty': item['serving_size_qty'],
        'serving_size_unit': item['serving_size_unit'],
        'calories_kcal': item['calories_kcal'],
        'protein_g': item['protein_g'],
        'carbs_g': item['carbs_g'],
        'fat_g': item['fat_g'],
      },
    ];
  }

  Map<String, dynamic>? _weightVariant(List<Map<String, dynamic>> vs) {
    for (final v in vs) {
      if ((v['portion_type'] ?? '').toString() == 'per_100g') return v;
    }
    return null;
  }

  Map<String, dynamic>? _servingVariant(List<Map<String, dynamic>> vs) {
    for (final v in vs) {
      if ((v['portion_type'] ?? '').toString() != 'per_100g') return v;
    }
    return null;
  }

  /// Human label for a serving, e.g. "1 plate", "170 g", "1 unit".
  String _servingLabel(Map<String, dynamic> v) {
    final qtyRaw = v['serving_size_qty'];
    final unit = (v['serving_size_unit'] ?? '').toString().trim();
    String qty = '';
    if (qtyRaw != null) {
      final d = double.tryParse(qtyRaw.toString());
      if (d != null) {
        qty = d == d.roundToDouble() ? d.toInt().toString() : d.toString();
      }
    }
    if (qty.isEmpty && unit.isEmpty) {
      return AppLocalizations.of(context).translate("diet_servings_unit");
    }
    return [qty, unit].where((s) => s.isNotEmpty).join(' ').trim();
  }

  Future<void> _promptAndLogFood(Map<String, dynamic> item) async {
    final vs = _variantsOf(item);
    final weight = _weightVariant(vs);
    final serving = _servingVariant(vs);

    if (weight != null && serving != null) {
      final mode = await _choosePortionMode(weight: weight, serving: serving);
      if (mode == null || !mounted) return;
      if (mode == 'serving') {
        await _logFoodByServing(serving);
      } else {
        await _logFoodByWeight(weight);
      }
    } else if (serving != null) {
      await _logFoodByServing(serving);
    } else {
      await _logFoodByWeight(weight ?? vs.first);
    }
  }

  Future<void> _logFoodByWeight(Map<String, dynamic> variant) async {
    final t = AppLocalizations.of(context);
    final foodId = int.tryParse(variant['id']?.toString() ?? '');
    if (foodId == null) return;

    // per_100g row -> base macros are per 100g, so factor = grams / 100.
    final grams = await _promptAmountWithPreview(
      title: t.translate("diet_enter_grams_title"),
      fieldUnit: t.translate("diet_grams_unit"),
      initial: "100",
      baseKcal: _numOf(variant['calories_kcal']),
      baseP: _numOf(variant['protein_g']),
      baseC: _numOf(variant['carbs_g']),
      baseF: _numOf(variant['fat_g']),
      factor: (v) => v / 100.0,
    );
    if (!mounted || grams == null || grams <= 0) return;

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
    _finishAndClose(daySummary);
  }

  Future<void> _logFoodByServing(Map<String, dynamic> variant) async {
    final t = AppLocalizations.of(context);
    final foodId = int.tryParse(variant['id']?.toString() ?? '');
    if (foodId == null) return;

    // per_serving row -> base macros are per 1 serving, so factor = servings.
    final servings = await _promptAmountWithPreview(
      title: t.translate("diet_enter_servings_title"),
      fieldUnit: t.translate("diet_servings_unit"),
      initial: "1",
      baseKcal: _numOf(variant['calories_kcal']),
      baseP: _numOf(variant['protein_g']),
      baseC: _numOf(variant['carbs_g']),
      baseF: _numOf(variant['fat_g']),
      factor: (v) => v,
    );
    if (!mounted || servings == null || servings <= 0) return;

    Map<String, dynamic>? daySummary;
    await _runLogAction(() async {
      final response = await DietService.addItemFromFoodsMasterServing(
        userId: widget.userId,
        mealId: widget.mealId,
        foodId: foodId,
        servings: servings,
        trainingDayId: widget.trainingDayId,
      );
      daySummary = response["day_summary"] is Map
          ? (response["day_summary"] as Map).cast<String, dynamic>()
          : null;
    }, successToast: t.translate("diet_item_added"));

    if (!mounted) return;
    _finishAndClose(daySummary);
  }

  void _finishAndClose(Map<String, dynamic>? daySummary) {
    final onLogged = widget.onLogged;
    setState(() => _isPopping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLogged(daySummary);
      });
    });
  }

  /// Bottom sheet asking "by serving" vs "by weight". Returns 'serving',
  /// 'weight', or null if dismissed. No "recommended" badge — both are shown
  /// plainly, serving first.
  Future<String?> _choosePortionMode({
    required Map<String, dynamic> weight,
    required Map<String, dynamic> serving,
  }) async {
    final t = AppLocalizations.of(context);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: TaqaUiColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: TaqaUiScale.insetsLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate("diet_choose_portion_title"),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(16),
                  fontWeight: FontWeight.w800,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(14)),
              _portionOption(
                icon: Icons.restaurant_outlined,
                title: t.translate("diet_portion_by_serving"),
                subtitle: _servingLabel(serving),
                onTap: () => Navigator.of(ctx).pop('serving'),
              ),
              _portionOption(
                icon: Icons.scale_outlined,
                title: t.translate("diet_portion_by_weight"),
                subtitle: t.translate("diet_portion_by_weight_sub"),
                onTap: () => Navigator.of(ctx).pop('weight'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(14),
        onTap: onTap,
        child: Container(
          padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiScale.radius(14),
            border: Border.all(
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: TaqaUiScale.sp(22),
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: TaqaUiScale.h(2)),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(12),
                            color: TaqaUiColors.unnamedColor1c1d17
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: TaqaUiScale.sp(20),
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _numOf(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  /// Amount input with a LIVE macro preview that updates as the user types.
  /// [factor] converts the entered amount into a multiplier over the base
  /// (per-serving or per-100g) macros — servings: (v)=>v ; grams: (v)=>v/100.
  /// Returns the entered amount, or null if cancelled.
  Future<double?> _promptAmountWithPreview({
    required String title,
    required String fieldUnit,
    required String initial,
    required double baseKcal,
    required double baseP,
    required double baseC,
    required double baseF,
    required double Function(double input) factor,
  }) async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: initial);
    final dark = TaqaUiColors.unnamedColor1c1d17;

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaqaUiColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final val =
              double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0;
          final f = val > 0 ? factor(val) : 0.0;
          int r(double x) => (!x.isFinite || x < 0) ? 0 : x.round();
          final kcal = r(baseKcal * f);
          final p = r(baseP * f);
          final c = r(baseC * f);
          final fat = r(baseF * f);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: SafeArea(
              child: Padding(
                padding: TaqaUiScale.insetsLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(16),
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(12)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setSheet(() {}),
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(20),
                              fontWeight: FontWeight.w700,
                              color: dark,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  TaqaUiScale.insetsLTRB(14, 12, 14, 12),
                              filled: true,
                              fillColor: dark.withValues(alpha: 0.04),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: TaqaUiScale.radius(12),
                                borderSide: BorderSide(
                                  color: dark.withValues(alpha: 0.15),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: TaqaUiScale.radius(12),
                                borderSide: BorderSide(color: dark, width: 1.2),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: TaqaUiScale.w(10)),
                        Text(
                          fieldUnit,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w600,
                            color: dark.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: TaqaUiScale.h(14)),
                    Text(
                      "$kcal ${t.translate("diet_kcal_label")} • "
                      "${t.translate("diet_p_short")} $p • "
                      "${t.translate("diet_c_short")} $c • "
                      "${t.translate("diet_f_short")} $fat",
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w600,
                        color: dark,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(16)),
                    InkWell(
                      borderRadius: TaqaUiScale.radius(14),
                      onTap: val > 0 ? () => Navigator.of(ctx).pop(val) : null,
                      child: Container(
                        width: double.infinity,
                        padding: TaqaUiScale.insetsLTRB(16, 14, 16, 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: val > 0
                              ? dark
                              : dark.withValues(alpha: 0.25),
                          borderRadius: TaqaUiScale.radius(14),
                        ),
                        child: Text(
                          t.translate("diet_log").toUpperCase(),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(14),
                            fontWeight: FontWeight.w800,
                            color: TaqaUiColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    ctrl.dispose();
    return result;
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
      // Same smart flow as logging: pick weight vs serving when both exist,
      // then a live-preview amount input. Macros computed locally (multiplying
      // the chosen variant's base macros) so they match the backend exactly.
      final vs = _variantsOf(item);
      final weight = _weightVariant(vs);
      final serving = _servingVariant(vs);

      String mode;
      Map<String, dynamic> chosen;
      if (weight != null && serving != null) {
        final m = await _choosePortionMode(weight: weight, serving: serving);
        if (m == null || !mounted) return;
        mode = m;
        chosen = m == 'serving' ? serving : weight;
      } else if (serving != null) {
        mode = 'serving';
        chosen = serving;
      } else {
        mode = 'weight';
        chosen = weight ?? vs.first;
      }

      final foodId = int.tryParse(chosen['id']?.toString() ?? '');
      if (foodId == null) return;

      final isServing = mode == 'serving';
      final baseKcal = _numOf(chosen['calories_kcal']);
      final baseP = _numOf(chosen['protein_g']);
      final baseC = _numOf(chosen['carbs_g']);
      final baseF = _numOf(chosen['fat_g']);

      final amount = await _promptAmountWithPreview(
        title: isServing
            ? t.translate("diet_enter_servings_title")
            : t.translate("diet_enter_grams_title"),
        fieldUnit: isServing
            ? t.translate("diet_servings_unit")
            : t.translate("diet_grams_unit"),
        initial: isServing ? "1" : "100",
        baseKcal: baseKcal,
        baseP: baseP,
        baseC: baseC,
        baseF: baseF,
        factor: isServing ? (v) => v : (v) => v / 100.0,
      );
      if (!mounted || amount == null || amount <= 0) return;

      final f = isServing ? amount : amount / 100.0;
      int r(double x) => (!x.isFinite || x < 0) ? 0 : x.round();

      double? grams;
      if (isServing) {
        final unit =
            (chosen['serving_size_unit'] ?? '').toString().toLowerCase();
        final ssq = _numOf(chosen['serving_size_qty']);
        grams = (unit == 'g' || unit == 'gram' || unit == 'grams') && ssq > 0
            ? ssq * amount
            : null;
      } else {
        grams = amount;
      }

      ingredient = {
        'name': _foodName(item),
        'grams': grams,
        'calories': r(baseKcal * f),
        'protein': r(baseP * f),
        'carbs': r(baseC * f),
        'fat': r(baseF * f),
        'food_id': foodId,
      };
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
        AppToast.show(
          widget.rootContext,
          successToast,
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        AppToast.show(
          widget.rootContext,
          "${t.translate("diet_failed_to_add_item")}: $e",
          type: AppToastType.error,
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int?> _intDialog({
    required String title,
    required String hint,
    required String unit,
    required String initial,
  }) async {
    final t = AppLocalizations.of(context);
    final text = await showTaqaTextValueDialog(
      context: context,
      title: title,
      initialValue: initial,
      keyboardType: TextInputType.number,
      unit: unit,
      confirmLabel: t.translate("diet_log").toUpperCase(),
    );
    if (text == null) return null;
    return int.tryParse(text.trim());
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
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.88;
    final sheetHeight = (maxSheetHeight - bottomInset).clamp(
      0.0,
      maxSheetHeight,
    );

    return PopScope(
      onPopInvokedWithResult: (_, _) => FocusScope.of(context).unfocus(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: sheetHeight,
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
                                : () {
                                    FocusScope.of(context).unfocus();
                                    Navigator.of(context).pop();
                                  },
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
                                color: TaqaUiColors.unnamedColor1c1d17
                                    .withValues(alpha: 0.10),
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
                                color: TaqaUiColors.unnamedColor1c1d17
                                    .withValues(alpha: 0.10),
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
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
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
      controller: _scrollCtrl,
      // +1 slot for the bottom "loading more" spinner when another page exists.
      itemCount: _results.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => SizedBox(height: TaqaUiScale.h(12)),
      itemBuilder: (ctx, i) {
        if (i >= _results.length) {
          // Trailing loader row; also nudges a fetch if the list is short.
          if (!_loadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          }
          return Padding(
            padding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(12)),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildResultItem(_results[i]);
      },
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
