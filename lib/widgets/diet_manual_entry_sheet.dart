import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../theme/app_theme.dart';
import 'diet_foods_master_picker_sheet.dart';

class DietManualEntrySheet extends StatefulWidget {
  const DietManualEntrySheet({
    super.key,
    required this.rootContext,
    required this.userId,
    required this.mealId,
    required this.mealTitle,
    this.trainingDayId,
    required this.onLogged,
  });

  final BuildContext rootContext;
  final int userId;
  final int mealId;
  final String mealTitle;
  final int? trainingDayId;
  final Future<void> Function(Map<String, dynamic>? daySummary) onLogged;

  @override
  State<DietManualEntrySheet> createState() => _DietManualEntrySheetState();
}

class _DietManualEntrySheetState extends State<DietManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _mealNameCtrl = TextEditingController();
  final List<_IngredientRow> _ingredients = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _mealNameCtrl.text = widget.mealTitle;
    // Start with one empty ingredient slot so the sheet doesn't look empty
    _ingredients.add(_IngredientRow(
      name: '',
      grams: null,
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      foodId: null,
    ));
  }

  @override
  void dispose() {
    _mealNameCtrl.dispose();
    for (final row in _ingredients) {
      row.dispose();
    }
    super.dispose();
  }

  void _addIngredientRow({
    String? name,
    double? grams,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    int? foodId,
  }) {
    setState(() {
      _ingredients.add(_IngredientRow(
        name: name ?? '',
        grams: grams,
        calories: calories ?? 0,
        protein: protein ?? 0,
        carbs: carbs ?? 0,
        fat: fat ?? 0,
        foodId: foodId,
      ));
    });
  }

  void _removeIngredientRow(int index) {
    final row = _ingredients.removeAt(index);
    row.dispose();
    setState(() {});
  }

  /// Add one ingredient from Foods Master: pick food + grams, preview macros, add editable row.
  Future<void> _addFromSearch() async {
    if (_loading) return;
    final t = AppLocalizations.of(context);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => DietFoodsMasterPickerSheet(
        title: t.translate("diet_manual_prefill_title"),
        requireGrams: true,
      ),
    );
    if (!mounted || result == null) return;

    final foodId = int.tryParse(result['food_id']?.toString() ?? '');
    final grams = double.tryParse(result['grams']?.toString() ?? '');
    if (foodId == null || foodId == 0 || grams == null || grams <= 0) return;

    setState(() => _loading = true);
    try {
      final preview = await DietService.previewManualItemFromFoodsMaster(
        userId: widget.userId,
        foodId: foodId,
        grams: grams,
      );
      if (!mounted) return;
      final itemName = (preview['item_name'] ?? '').toString().trim();
      final cal = int.tryParse(preview['calories']?.toString() ?? '') ?? 0;
      final p = int.tryParse(preview['protein_g']?.toString() ?? '') ?? 0;
      final c = int.tryParse(preview['carbs_g']?.toString() ?? '') ?? 0;
      final f = int.tryParse(preview['fat_g']?.toString() ?? '') ?? 0;
      _addIngredientRow(
        name: itemName.isNotEmpty ? itemName : (result['food_name'] ?? '').toString().trim(),
        grams: grams,
        calories: cal,
        protein: p,
        carbs: c,
        fat: f,
        foodId: foodId,
      );
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text("${t.translate("diet_failed_to_add_item")}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addManualIngredient() {
    _addIngredientRow();
  }

  List<Map<String, dynamic>> _buildIngredientsPayload() {
    final list = <Map<String, dynamic>>[];
    for (final row in _ingredients) {
      final name = row.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      final cal = int.tryParse(row.calCtrl.text.trim()) ?? 0;
      final p = int.tryParse(row.proteinCtrl.text.trim()) ?? 0;
      final c = int.tryParse(row.carbsCtrl.text.trim()) ?? 0;
      final f = int.tryParse(row.fatCtrl.text.trim()) ?? 0;
      final gramsStr = row.gramsCtrl.text.trim();
      final grams = gramsStr.isEmpty ? null : double.tryParse(gramsStr);
      list.add({
        'ingredient_name': name,
        'calories': cal,
        'protein_g': p,
        'carbs_g': c,
        'fat_g': f,
        if (grams != null) 'grams': grams,
        if (row.foodId != null) 'food_id': row.foodId,
      });
    }
    return list;
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final ingredients = _buildIngredientsPayload();
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        SnackBar(content: Text(t.translate("diet_manual_at_least_one_ingredient"))),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final mealName = _mealNameCtrl.text.trim();
      final response = await DietService.saveManualEntry(
        userId: widget.userId,
        mealId: widget.mealId,
        mealName: mealName.isEmpty ? null : mealName,
        ingredients: ingredients,
        trainingDayId: widget.trainingDayId,
      );

      if (!mounted) return;
      final daySummary = response["day_summary"] is Map
          ? (response["day_summary"] as Map).cast<String, dynamic>()
          : null;

      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text(t.translate("diet_item_added"))),
        );
      }

      final onLogged = widget.onLogged;
      final summary = daySummary;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLogged(summary);
      });
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text("${t.translate("diet_failed_to_add_item")}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    height: 5,
                    width: 44,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.translate("diet_manual_entry_title"),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mealNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: t.translate("diet_add_meal_name"),
                      hintText: t.translate("diet_add_meal_name_hint"),
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: AppColors.cardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.translate("diet_ingredients_title"),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _addFromSearch,
                        icon: const Icon(Icons.search, size: 20),
                        label: Text(t.translate("diet_manual_prefill_button")),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: t.translate("diet_add_ingredient_manual"),
                        onPressed: _loading ? null : _addManualIngredient,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                      ),
                    ],
                  ),
                  if (_ingredients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        t.translate("diet_ingredients_empty"),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _ingredients.length,
                      itemBuilder: (context, idx) {
                        final row = _ingredients[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _IngredientTile(
                            row: row,
                            onRemove: () => _removeIngredientRow(idx),
                            loading: _loading,
                            t: t,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t.translate("diet_log")),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({
    required this.row,
    required this.onRemove,
    required this.loading,
    required this.t,
  });

  final _IngredientRow row;
  final VoidCallback onRemove;
  final bool loading;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.translate("diet_ingredient_name"),
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) {
                      return t.translate("diet_ingredient_name_required");
                    }
                    return null;
                  },
                ),
              ),
              IconButton(
                onPressed: loading ? null : onRemove,
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.gramsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.translate("diet_manual_grams"),
                    hintText: t.translate("diet_manual_grams_optional"),
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: AppColors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return null;
                    final val = double.tryParse(v!.trim());
                    if (val == null || val < 0) return t.translate("diet_manual_grams_invalid");
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.translate("diet_manual_macros"),
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.calCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.translate("diet_manual_calories"),
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  validator: (v) {
                    final val = int.tryParse(v?.trim() ?? '');
                    if (val == null || val < 0) return t.translate("diet_manual_calories_invalid");
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.proteinCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.translate("protein"),
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  validator: (v) {
                    final val = int.tryParse(v?.trim() ?? '');
                    if (val == null || val < 0) return t.translate("diet_manual_macro_invalid");
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.carbsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.translate("diet_carbs"),
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  validator: (v) {
                    final val = int.tryParse(v?.trim() ?? '');
                    if (val == null || val < 0) return t.translate("diet_manual_macro_invalid");
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.fatCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t.translate("diet_fat"),
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  validator: (v) {
                    final val = int.tryParse(v?.trim() ?? '');
                    if (val == null || val < 0) return t.translate("diet_manual_macro_invalid");
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientRow {
  _IngredientRow({
    String name = '',
    double? grams,
    int calories = 0,
    int protein = 0,
    int carbs = 0,
    int fat = 0,
    int? foodId,
  })  : nameCtrl = TextEditingController(text: name),
        gramsCtrl = TextEditingController(
          text: grams != null && grams > 0 ? grams.toString() : '',
        ),
        calCtrl = TextEditingController(text: calories > 0 ? calories.toString() : ''),
        proteinCtrl = TextEditingController(text: protein > 0 ? protein.toString() : ''),
        carbsCtrl = TextEditingController(text: carbs > 0 ? carbs.toString() : ''),
        fatCtrl = TextEditingController(text: fat > 0 ? fat.toString() : ''),
        foodId = foodId;

  final TextEditingController nameCtrl;
  final TextEditingController gramsCtrl;
  final TextEditingController calCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController fatCtrl;
  final int? foodId;

  void dispose() {
    nameCtrl.dispose();
    gramsCtrl.dispose();
    calCtrl.dispose();
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
  }
}
