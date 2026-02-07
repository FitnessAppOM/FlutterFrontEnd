import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../services/diet/nutrition_search_service.dart';
import '../theme/app_theme.dart';

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
          : await NutritionSearchService.searchRestaurants(q: q, limit: 25, offset: 0);
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
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text(successToast)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text("${t.translate("diet_failed_to_add_item")}: $e")),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => value = v,
              decoration: InputDecoration(
                hintText: hint,
                suffixText: unit,
              ),
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
              decoration: InputDecoration(
                hintText: hint,
                suffixText: unit,
              ),
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

  String _foodTitle(Map<String, dynamic> item) {
    final name = (item['food_name'] ?? '').toString().trim();
    final cat = (item['category'] ?? '').toString().trim();
    return cat.isNotEmpty ? "$name • $cat" : name;
  }

  String _restaurantTitle(Map<String, dynamic> item) {
    final brand = (item['brand_or_restaurant'] ?? '').toString().trim();
    final name = (item['food_name'] ?? '').toString().trim();
    return brand.isNotEmpty ? "$brand • $name" : name;
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16),
            child: Column(
              children: [
                Container(
                  height: 5,
                  width: 44,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.translate("diet_add_item_title"),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.mealTitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                _isPopping
                    ? Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          t.translate("diet_search_hint"),
                          style: const TextStyle(color: Colors.white38),
                        ),
                      )
                    : TextField(
                        controller: _qCtrl,
                        onChanged: (_) => _scheduleSearch(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: t.translate("diet_search_hint"),
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: AppColors.cardDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 10),
                DefaultTabController(
                  key: ValueKey('diet_search_${widget.mealId}_$hashCode'),
                  length: 2,
                  child: Builder(
                    builder: (context) {
                      return Column(
                        children: [
                          TabBar(
                            onTap: (i) {
                              setState(() {
                                _tabIndex = i;
                                _results = [];
                                _error = null;
                              });
                              _scheduleSearch();
                            },
                            tabs: [
                              Tab(text: t.translate("diet_tab_foods")),
                              Tab(text: t.translate("diet_tab_restaurants")),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    },
                  ),
                ),
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
          style: const TextStyle(color: AppColors.errorRed),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          t.translate("diet_no_results"),
          style: const TextStyle(color: Colors.white60),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) =>
          const Divider(color: AppColors.dividerDark, height: 1),
      itemBuilder: (ctx, i) {
        final it = _results[i];
        final title = _tabIndex == 0 ? _foodTitle(it) : _restaurantTitle(it);
        final subtitle = _macroSubtitle(it);
        return ListTile(
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
          trailing: const Icon(Icons.add_circle_outline, color: Colors.white70),
          onTap: _tabIndex == 0 ? () => _promptAndLogFood(it) : () => _promptAndLogRestaurant(it),
        );
      },
    );
  }
}

