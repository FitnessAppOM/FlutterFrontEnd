import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/diet/nutrition_search_service.dart';
import '../theme/app_theme.dart';

class DietFoodsMasterPickerSheet extends StatefulWidget {
  const DietFoodsMasterPickerSheet({
    super.key,
    required this.title,
    this.requireGrams = false,
  });

  final String title;
  final bool requireGrams;

  @override
  State<DietFoodsMasterPickerSheet> createState() => _DietFoodsMasterPickerSheetState();
}

class _DietFoodsMasterPickerSheetState extends State<DietFoodsMasterPickerSheet> {
  final _qCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  bool _isPopping = false;

  List<Map<String, dynamic>> _results = [];

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await NutritionSearchService.searchFoods(q: q, limit: 25, offset: 0);
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

  Future<void> _selectFood(Map<String, dynamic> item) async {
    final foodId = int.tryParse(item['id']?.toString() ?? '');
    if (foodId == null) return;
    final foodName = (item['food_name'] ?? '').toString().trim();

    double? grams;
    if (widget.requireGrams) {
      final t = AppLocalizations.of(context);
      grams = await _numberDialog(
        title: t.translate("diet_enter_grams_title"),
        hint: t.translate("diet_grams_hint"),
        unit: t.translate("diet_grams_unit"),
        initial: "100",
      );
      if (!mounted || grams == null || grams <= 0) return;
    }

    setState(() => _isPopping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop({
        'food_id': foodId,
        'food_name': foodName,
        if (grams != null) 'grams': grams,
      });
    });
  }

  Future<double?> _numberDialog({
    required String title,
    required String hint,
    required String unit,
    required String initial,
  }) async {
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
              child: Text(AppLocalizations.of(context).translate("common_cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(value.trim());
                Navigator.of(ctx).pop(v);
              },
              child: Text(AppLocalizations.of(context).translate("diet_log")),
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

  String _macroSubtitle(Map<String, dynamic> item) {
    final t = AppLocalizations.of(context);
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
          height: MediaQuery.sizeOf(context).height * 0.82,
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
                        widget.title,
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
                const SizedBox(height: 12),
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
        final title = _foodTitle(it);
        final subtitle = _macroSubtitle(it);
        return ListTile(
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
          trailing: const Icon(Icons.add_circle_outline, color: Colors.white70),
          onTap: () => _selectFood(it),
        );
      },
    );
  }
}
