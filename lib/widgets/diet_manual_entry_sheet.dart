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

  /// Use a stable parent context (Scaffold) for SnackBars.
  /// Avoids RenderObject 'attached' assertions when the sheet is closing.
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
  final _nameCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController();
  final List<_IngredientRow> _ingredients = [];

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _gramsCtrl.dispose();
    for (final row in _ingredients) {
      row.amountCtrl.removeListener(_recalculateIngredientMacros);
      row.dispose();
    }
    super.dispose();
  }

  void _addIngredientRow({String? name, String? unit, int? foodId, double? baseGrams}) {
    setState(() {
      final row = _IngredientRow(
        name: name ?? '',
        unit: unit ?? '',
        foodId: foodId,
        baseGrams: baseGrams,
      );
      _ingredients.add(row);
      // Add listener to recalculate macros when amount changes
      row.amountCtrl.addListener(_recalculateIngredientMacros);
    });
    _recalculateIngredientMacros();
  }

  void _removeIngredientRow(int index) {
    final row = _ingredients.removeAt(index);
    row.amountCtrl.removeListener(_recalculateIngredientMacros);
    // Subtract this ingredient's macros before disposing
    if (row.hasMacros) {
      final amount = double.tryParse(row.amountCtrl.text.trim());
      if (amount != null && amount > 0) {
        final macros = row.getMacrosForAmount(amount);
        _subtractMacrosFromFields(macros);
      }
    }
    row.dispose();
    setState(() {});
  }

  void _addMacrosToFields(Map<String, int> macros) {
    final currentCal = int.tryParse(_caloriesCtrl.text.trim()) ?? 0;
    final currentP = int.tryParse(_proteinCtrl.text.trim()) ?? 0;
    final currentC = int.tryParse(_carbsCtrl.text.trim()) ?? 0;
    final currentF = int.tryParse(_fatCtrl.text.trim()) ?? 0;

    _caloriesCtrl.text = (currentCal + (macros['calories'] ?? 0)).toString();
    _proteinCtrl.text = (currentP + (macros['protein_g'] ?? 0)).toString();
    _carbsCtrl.text = (currentC + (macros['carbs_g'] ?? 0)).toString();
    _fatCtrl.text = (currentF + (macros['fat_g'] ?? 0)).toString();
  }

  void _subtractMacrosFromFields(Map<String, int> macros) {
    final currentCal = int.tryParse(_caloriesCtrl.text.trim()) ?? 0;
    final currentP = int.tryParse(_proteinCtrl.text.trim()) ?? 0;
    final currentC = int.tryParse(_carbsCtrl.text.trim()) ?? 0;
    final currentF = int.tryParse(_fatCtrl.text.trim()) ?? 0;

    _caloriesCtrl.text = (currentCal - (macros['calories'] ?? 0)).clamp(0, double.infinity).toInt().toString();
    _proteinCtrl.text = (currentP - (macros['protein_g'] ?? 0)).clamp(0, double.infinity).toInt().toString();
    _carbsCtrl.text = (currentC - (macros['carbs_g'] ?? 0)).clamp(0, double.infinity).toInt().toString();
    _fatCtrl.text = (currentF - (macros['fat_g'] ?? 0)).clamp(0, double.infinity).toInt().toString();
  }

  void _recalculateIngredientMacros() {
    if (!mounted) return;
    // Recalculate all ingredient macros and update form fields
    // First, get current base (subtract all current ingredient macros)
    int baseCal = int.tryParse(_caloriesCtrl.text.trim()) ?? 0;
    int baseP = int.tryParse(_proteinCtrl.text.trim()) ?? 0;
    int baseC = int.tryParse(_carbsCtrl.text.trim()) ?? 0;
    int baseF = int.tryParse(_fatCtrl.text.trim()) ?? 0;

    // Subtract all ingredient macros to get pure base
    for (final row in _ingredients) {
      if (!row.hasMacros) continue;
      final amount = double.tryParse(row.amountCtrl.text.trim());
      if (amount != null && amount > 0) {
        final macros = row.getMacrosForAmount(amount);
        baseCal -= macros['calories'] ?? 0;
        baseP -= macros['protein_g'] ?? 0;
        baseC -= macros['carbs_g'] ?? 0;
        baseF -= macros['fat_g'] ?? 0;
      }
    }

    // Now add all ingredient macros back (with updated amounts)
    int totalIngCal = 0;
    int totalIngP = 0;
    int totalIngC = 0;
    int totalIngF = 0;

    for (final row in _ingredients) {
      if (!row.hasMacros) continue;
      final amount = double.tryParse(row.amountCtrl.text.trim());
      if (amount != null && amount > 0) {
        final macros = row.getMacrosForAmount(amount);
        totalIngCal += macros['calories'] ?? 0;
        totalIngP += macros['protein_g'] ?? 0;
        totalIngC += macros['carbs_g'] ?? 0;
        totalIngF += macros['fat_g'] ?? 0;
      }
    }

    // Update form fields with base + ingredients
    final combinedCal = baseCal + totalIngCal;
    final combinedP = baseP + totalIngP;
    final combinedC = baseC + totalIngC;
    final combinedF = baseF + totalIngF;

    if (_caloriesCtrl.text != combinedCal.toString()) {
      _caloriesCtrl.text = combinedCal.toString();
    }
    if (_proteinCtrl.text != combinedP.toString()) {
      _proteinCtrl.text = combinedP.toString();
    }
    if (_carbsCtrl.text != combinedC.toString()) {
      _carbsCtrl.text = combinedC.toString();
    }
    if (_fatCtrl.text != combinedF.toString()) {
      _fatCtrl.text = combinedF.toString();
    }
  }

  Future<void> _openFoodsMasterPrefill() async {
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
    if (foodId == null || grams == null || grams <= 0) return;

    // Ask user whether to use this as main item or ingredient.
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t.translate("diet_manual_search_choice_title")),
          content: Text(t.translate("diet_manual_search_choice_body")),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('ingredient'),
              child: Text(t.translate("diet_manual_search_as_ingredient")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('item'),
              child: Text(t.translate("diet_manual_search_as_item")),
            ),
          ],
        );
      },
    );
    if (!mounted || choice == null) return;

    if (choice == 'ingredient') {
      final foodName = (result['food_name'] ?? '').toString().trim();
      if (foodName.isEmpty) return;
      
      // Fetch macros for this ingredient
      setState(() => _loading = true);
      try {
        final preview = await DietService.previewManualItemFromFoodsMaster(
          userId: widget.userId,
          foodId: foodId,
          grams: grams,
        );
        if (!mounted) return;
        
        // Add ingredient row with macros
        _addIngredientRow(
          name: foodName,
          unit: 'g',
          foodId: foodId,
          baseGrams: grams,
        );
        
        if (_ingredients.isNotEmpty) {
          final last = _ingredients.last;
          last.amountCtrl.text = grams.toString();
          // Store macros in the row (per baseGrams, e.g., per 100g)
          last.setMacros(
            calories: int.tryParse(preview['calories']?.toString() ?? '') ?? 0,
            protein: int.tryParse(preview['protein_g']?.toString() ?? '') ?? 0,
            carbs: int.tryParse(preview['carbs_g']?.toString() ?? '') ?? 0,
            fat: int.tryParse(preview['fat_g']?.toString() ?? '') ?? 0,
          );
          // Recalculate all ingredient macros (this will add this new one's macros)
          _recalculateIngredientMacros();
        }
      } catch (e) {
        if (!mounted) return;
        // If preview fails, still add ingredient but without macros
        _addIngredientRow(name: foodName, unit: 'g');
        if (_ingredients.isNotEmpty) {
          final last = _ingredients.last;
          last.amountCtrl.text = grams.toString();
        }
        if (widget.rootContext.mounted) {
          ScaffoldMessenger.of(widget.rootContext).showSnackBar(
            SnackBar(
              content: Text("${t.translate("diet_failed_to_add_item")}: $e"),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    // Default: use as main item with macro prefill.
    setState(() => _loading = true);
    try {
      final preview = await DietService.previewManualItemFromFoodsMaster(
        userId: widget.userId,
        foodId: foodId,
        grams: grams,
      );

      if (!mounted) return;
      _nameCtrl.text = (preview['item_name'] ?? '').toString();
      _gramsCtrl.text = preview['grams']?.toString() ?? grams.toString();
      _caloriesCtrl.text = preview['calories']?.toString() ?? '';
      _proteinCtrl.text = preview['protein_g']?.toString() ?? '';
      _carbsCtrl.text = preview['carbs_g']?.toString() ?? '';
      _fatCtrl.text = preview['fat_g']?.toString() ?? '';
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(
            content: Text("${t.translate("diet_failed_to_add_item")}: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _buildIngredientsPayload() {
    final list = <Map<String, dynamic>>[];
    for (final row in _ingredients) {
      final name = row.nameCtrl.text.trim();
      final amountText = row.amountCtrl.text.trim();
      final unit = row.unitCtrl.text.trim();

      final hasAny = name.isNotEmpty || amountText.isNotEmpty || unit.isNotEmpty;
      if (!hasAny) continue;

      final amount = amountText.isEmpty ? null : double.tryParse(amountText);
      list.add({
        'ingredient_name': name,
        if (amount != null) 'amount': amount,
        if (unit.isNotEmpty) 'unit': unit,
      });
    }
    return list;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final t = AppLocalizations.of(context);
    setState(() => _loading = true);

    try {
      final calories = int.tryParse(_caloriesCtrl.text.trim()) ?? 0;
      final protein = int.tryParse(_proteinCtrl.text.trim()) ?? 0;
      final carbs = int.tryParse(_carbsCtrl.text.trim()) ?? 0;
      final fat = int.tryParse(_fatCtrl.text.trim()) ?? 0;
      final grams = _gramsCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_gramsCtrl.text.trim());
      final ingredients = _buildIngredientsPayload();

      final response = await DietService.addManualItem(
        userId: widget.userId,
        mealId: widget.mealId,
        itemName: _nameCtrl.text.trim(),
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        grams: grams,
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

      // Capture before closing sheet so we don't use widget/context after pop
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
          SnackBar(
            content: Text("${t.translate("diet_failed_to_add_item")}: $e"),
          ),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.mealTitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: t.translate("diet_manual_item_name"),
                              hintText: t.translate("diet_manual_item_name_hint"),
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
                            validator: (v) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return t.translate("diet_manual_item_name_required");
                              }
                              if (trimmed.length > 200) {
                                return t.translate("diet_manual_item_name_too_long");
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _openFoodsMasterPrefill,
                            icon: const Icon(Icons.search),
                            label: Text(t.translate("diet_manual_prefill_button")),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _caloriesCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: t.translate("diet_manual_calories"),
                                    labelStyle: const TextStyle(color: Colors.white70),
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
                                  validator: (v) {
                                    final val = int.tryParse(v?.trim() ?? '');
                                    if (val == null || val < 0) {
                                      return t.translate("diet_manual_calories_invalid");
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _gramsCtrl,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: t.translate("diet_manual_grams"),
                                    hintText: t.translate("diet_manual_grams_optional"),
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
                                  validator: (v) {
                                    if (v?.trim().isEmpty ?? true) return null;
                                    final val = double.tryParse(v!.trim());
                                    if (val == null || val < 0) {
                                      return t.translate("diet_manual_grams_invalid");
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t.translate("diet_manual_macros"),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _proteinCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: t.translate("protein"),
                                    labelStyle: const TextStyle(color: Colors.white70),
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
                                  validator: (v) {
                                    final val = int.tryParse(v?.trim() ?? '');
                                    if (val == null || val < 0) {
                                      return t.translate("diet_manual_macro_invalid");
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _carbsCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: t.translate("diet_carbs"),
                                    labelStyle: const TextStyle(color: Colors.white70),
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
                                  validator: (v) {
                                    final val = int.tryParse(v?.trim() ?? '');
                                    if (val == null || val < 0) {
                                      return t.translate("diet_manual_macro_invalid");
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _fatCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: t.translate("diet_fat"),
                                    labelStyle: const TextStyle(color: Colors.white70),
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
                                  validator: (v) {
                                    final val = int.tryParse(v?.trim() ?? '');
                                    if (val == null || val < 0) {
                                      return t.translate("diet_manual_macro_invalid");
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
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
                              IconButton(
                                tooltip: t.translate("diet_add_ingredient"),
                                onPressed: _loading ? null : () => _addIngredientRow(),
                                icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                              ),
                            ],
                          ),
                          if (_ingredients.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                t.translate("diet_ingredients_empty"),
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                              ),
                            ),
                          const SizedBox(height: 8),
                          ..._ingredients.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final row = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    TextFormField(
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
                                        final name = v?.trim() ?? '';
                                        final amount = row.amountCtrl.text.trim();
                                        final unit = row.unitCtrl.text.trim();
                                        final hasAny = name.isNotEmpty || amount.isNotEmpty || unit.isNotEmpty;
                                        if (hasAny && name.isEmpty) {
                                          return t.translate("diet_ingredient_name_required");
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: row.amountCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              labelText: t.translate("diet_ingredient_amount"),
                                              hintText: t.translate("diet_ingredient_optional"),
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
                                              final trimmed = v?.trim() ?? '';
                                              if (trimmed.isEmpty) return null;
                                              final val = double.tryParse(trimmed);
                                              if (val == null || val <= 0) {
                                                return t.translate("diet_ingredient_amount_invalid");
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextFormField(
                                            controller: row.unitCtrl,
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              labelText: t.translate("diet_ingredient_unit"),
                                              hintText: t.translate("diet_ingredient_optional"),
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
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: t.translate("diet_remove_ingredient"),
                                          onPressed: _loading ? null : () => _removeIngredientRow(idx),
                                          icon: const Icon(Icons.close, color: Colors.white54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
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

class _IngredientRow {
  _IngredientRow({
    String name = '',
    String unit = '',
    int? foodId,
    double? baseGrams,
  })  : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(),
        unitCtrl = TextEditingController(text: unit),
        _foodId = foodId,
        _baseGrams = baseGrams ?? 100.0;

  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController unitCtrl;
  final int? _foodId;
  final double _baseGrams;

  // Cached macros per 100g (or baseGrams) from Foods Master
  int _cachedCalories = 0;
  int _cachedProtein = 0;
  int _cachedCarbs = 0;
  int _cachedFat = 0;

  void setMacros({required int calories, required int protein, required int carbs, required int fat}) {
    _cachedCalories = calories;
    _cachedProtein = protein;
    _cachedCarbs = carbs;
    _cachedFat = fat;
  }

  Map<String, int> getMacrosForAmount(double? amount) {
    if (_foodId == null || amount == null || amount <= 0) {
      return {'calories': 0, 'protein_g': 0, 'carbs_g': 0, 'fat_g': 0};
    }
    // Scale macros based on amount vs baseGrams
    final scale = amount / _baseGrams;
    return {
      'calories': (_cachedCalories * scale).round(),
      'protein_g': (_cachedProtein * scale).round(),
      'carbs_g': (_cachedCarbs * scale).round(),
      'fat_g': (_cachedFat * scale).round(),
    };
  }

  bool get hasMacros => _foodId != null && _cachedCalories > 0;

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    unitCtrl.dispose();
  }
}
