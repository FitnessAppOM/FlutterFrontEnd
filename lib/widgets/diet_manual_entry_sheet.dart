import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/diet_service.dart';
import '../theme/app_theme.dart';

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

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _gramsCtrl.dispose();
    super.dispose();
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

      final response = await DietService.addManualItem(
        userId: widget.userId,
        mealId: widget.mealId,
        itemName: _nameCtrl.text.trim(),
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        grams: grams,
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
