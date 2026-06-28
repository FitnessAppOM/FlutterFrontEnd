import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import 'diet_item_search_sheet.dart';

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

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw.replaceAll(',', '.')) ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _mealNameCtrl.text = widget.mealTitle;
    // Start with one empty ingredient slot so the sheet doesn't look empty
    _ingredients.add(
      _IngredientRow(
        name: '',
        grams: null,
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        foodId: null,
      ),
    );
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
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    int? foodId,
  }) {
    setState(() {
      _ingredients.add(
        _IngredientRow(
          name: name ?? '',
          grams: grams,
          calories: calories ?? 0,
          protein: protein ?? 0,
          carbs: carbs ?? 0,
          fat: fat ?? 0,
          foodId: foodId,
        ),
      );
    });
  }

  void _removeIngredientRow(int index) {
    final row = _ingredients.removeAt(index);
    row.dispose();
    setState(() {});
  }

  /// Open the same food/restaurant search sheet used for logging meal items.
  Future<void> _addFromSearch() async {
    if (_loading) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaqaUiColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(15)),
        ),
      ),
      builder: (_) => DietItemSearchSheet(
        rootContext: widget.rootContext,
        userId: widget.userId,
        mealId: widget.mealId,
        mealTitle: widget.mealTitle,
        trainingDayId: widget.trainingDayId,
        initialTab: 0,
        onLogged: widget.onLogged,
        onPickForManualEntry: (ingredient) {
          _addIngredientRow(
            name: ingredient['name'] as String?,
            grams: ingredient['grams'] as double?,
            calories: ingredient['calories'] as double?,
            protein: ingredient['protein'] as double?,
            carbs: ingredient['carbs'] as double?,
            fat: ingredient['fat'] as double?,
            foodId: ingredient['food_id'] as int?,
          );
        },
      ),
    );
  }

  void _addManualIngredient() {
    _addIngredientRow();
  }

  List<Map<String, dynamic>> _buildIngredientsPayload() {
    final list = <Map<String, dynamic>>[];
    for (final row in _ingredients) {
      final name = row.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      final cal = _asDouble(row.calCtrl.text);
      final p = _asDouble(row.proteinCtrl.text);
      final c = _asDouble(row.carbsCtrl.text);
      final f = _asDouble(row.fatCtrl.text);
      final gramsStr = row.gramsCtrl.text.trim();
      final grams = gramsStr.isEmpty ? null : _asDouble(gramsStr);
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
        SnackBar(
          content: Text(t.translate("diet_manual_at_least_one_ingredient")),
        ),
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
        ScaffoldMessenger.of(
          widget.rootContext,
        ).showSnackBar(SnackBar(content: Text(t.translate("diet_item_added"))));
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(20, 12, 20, 20),
            child: Form(
              key: _formKey,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.translate("diet_manual_entry_title"),
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
                      IconButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(16)),
                  Container(
                    width: double.infinity,
                    padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
                    decoration: BoxDecoration(
                      color: TaqaUiColors.white,
                      borderRadius: TaqaUiScale.radius(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate("diet_add_meal_name"),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w700,
                            height: 25 / 15,
                            letterSpacing: 0,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(8)),
                        TextFormField(
                          controller: _mealNameCtrl,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w400,
                            height: 21 / 15,
                            letterSpacing: 0,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                          decoration: _borderlessFieldDecoration(
                            hintText: t.translate("diet_add_meal_name_hint"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(20)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.translate("diet_ingredients_title"),
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
                      IconButton(
                        tooltip: t.translate("diet_add_ingredient_manual"),
                        onPressed: _loading ? null : _addManualIngredient,
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(8)),
                  InkWell(
                    borderRadius: TaqaUiScale.radius(15),
                    onTap: _loading ? null : _addFromSearch,
                    child: Container(
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
                          Text(
                            "Search",
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(15),
                              letterSpacing: 0,
                              color: TaqaUiColors.unnamedColorE3e3e3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_ingredients.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: TaqaUiScale.h(8)),
                      child: Text(
                        t.translate("diet_ingredients_empty"),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(12),
                          color: TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _ingredients.length,
                      itemBuilder: (context, idx) {
                        final row = _ingredients[idx];
                        return Padding(
                          padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
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
                  SizedBox(height: TaqaUiScale.h(20)),
                  Material(
                    color: TaqaUiColors.unnamedColorE4e93b,
                    borderRadius: TaqaUiScale.radius(5),
                    child: InkWell(
                      borderRadius: TaqaUiScale.radius(5),
                      onTap: _loading ? null : _submit,
                      child: SizedBox(
                        width: double.infinity,
                        height: TaqaUiScale.h(45),
                        child: Center(
                          child: _loading
                              ? SizedBox(
                                  height: TaqaUiScale.h(18),
                                  width: TaqaUiScale.w(18),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                  ),
                                )
                              : Text(
                                  t.translate("diet_log").toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
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
          ),
        ),
      ),
    );
  }
}

TextStyle _hintTextStyle() => TextStyle(
  fontFamily: TaqaUiFontFamilies.interTight,
  fontSize: TaqaUiScale.sp(15),
  fontWeight: FontWeight.w400,
  height: 21 / 15,
  letterSpacing: 0,
  color: TaqaUiColors.unnamedColorE3e3e3,
);

InputDecoration _borderlessFieldDecoration({String? hintText}) {
  return InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.zero,
    hintText: hintText,
    hintStyle: _hintTextStyle(),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

InputDecoration _underlineFieldDecoration({String? hintText}) {
  final lineSide = BorderSide(color: TaqaUiColors.unnamedColorE3e3e3);
  return InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
    hintText: hintText,
    hintStyle: _hintTextStyle(),
    border: UnderlineInputBorder(borderSide: lineSide),
    enabledBorder: UnderlineInputBorder(borderSide: lineSide),
    errorBorder: UnderlineInputBorder(borderSide: lineSide),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: TaqaUiColors.unnamedColor1c1d17),
    ),
    focusedErrorBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: TaqaUiColors.unnamedColor1c1d17),
    ),
  );
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
    final fieldStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(15),
      fontWeight: FontWeight.w400,
      height: 21 / 15,
      letterSpacing: 0,
      color: TaqaUiColors.unnamedColor1c1d17,
    );
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.nameCtrl,
                  style: fieldStyle,
                  decoration: _underlineFieldDecoration(
                    hintText: t.translate("diet_ingredient_name"),
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
                icon: Icon(
                  Icons.close,
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          TextFormField(
            controller: row.gramsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: fieldStyle,
            decoration: _underlineFieldDecoration(
              hintText: t.translate("diet_manual_grams"),
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
          SizedBox(height: TaqaUiScale.h(10)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.calCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: fieldStyle,
                  decoration: _underlineFieldDecoration(hintText: "Cals"),
                  validator: (v) {
                    final val = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    if (val == null || val < 0) {
                      return t.translate("diet_manual_calories_invalid");
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: TaqaUiScale.w(16)),
              Expanded(
                child: TextFormField(
                  controller: row.proteinCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: fieldStyle,
                  decoration: _underlineFieldDecoration(hintText: "Prtn"),
                  validator: (v) {
                    final val = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    if (val == null || val < 0) {
                      return t.translate("diet_manual_macro_invalid");
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.carbsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: fieldStyle,
                  decoration: _underlineFieldDecoration(
                    hintText: t.translate("diet_carbs"),
                  ),
                  validator: (v) {
                    final val = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    if (val == null || val < 0) {
                      return t.translate("diet_manual_macro_invalid");
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: TaqaUiScale.w(16)),
              Expanded(
                child: TextFormField(
                  controller: row.fatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: fieldStyle,
                  decoration: _underlineFieldDecoration(
                    hintText: t.translate("diet_fat"),
                  ),
                  validator: (v) {
                    final val = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    if (val == null || val < 0) {
                      return t.translate("diet_manual_macro_invalid");
                    }
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
  static String _numToText(double value) {
    if (value <= 0) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  _IngredientRow({
    String name = '',
    double? grams,
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    this.foodId,
  }) : nameCtrl = TextEditingController(text: name),
       gramsCtrl = TextEditingController(
         text: grams != null && grams > 0 ? grams.toString() : '',
       ),
       calCtrl = TextEditingController(text: _numToText(calories)),
       proteinCtrl = TextEditingController(text: _numToText(protein)),
       carbsCtrl = TextEditingController(text: _numToText(carbs)),
       fatCtrl = TextEditingController(text: _numToText(fat));

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
