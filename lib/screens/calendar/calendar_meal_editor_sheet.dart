import 'dart:async';

import 'package:flutter/material.dart';

import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/components/taqa_value_dialog.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/day_timeline_service.dart';
import '../../services/diet/diet_service.dart';
import '../../widgets/diet_item_search_sheet.dart';
import '../../widgets/diet_manual_entry_sheet.dart';
import '../../widgets/diet_photo_entry_sheet.dart';

class CalendarMealEditorSheet extends StatefulWidget {
  const CalendarMealEditorSheet({
    super.key,
    required this.event,
    required this.mealDate,
    required this.onChanged,
  });

  final DayTimelineEvent event;
  final DateTime mealDate;
  final Future<void> Function() onChanged;

  @override
  State<CalendarMealEditorSheet> createState() =>
      _CalendarMealEditorSheetState();
}

class _CalendarMealEditorSheetState extends State<CalendarMealEditorSheet> {
  bool _working = false;

  int get _mealId =>
      int.tryParse(widget.event.id.replaceFirst('meal-', '')) ?? 0;
  int get _planId => _int(widget.event.details['plan_id']);
  bool get _isPlanned => widget.event.type == 'planned_meal';

  List<Map<String, dynamic>> get _items =>
      (widget.event.details['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);

  Future<int?> _userId() async {
    final value = await AccountStorage.getUserId();
    return value != null && value > 0 ? value : null;
  }

  Future<void> _finish() async {
    final onChanged = widget.onChanged;
    if (mounted) Navigator.of(context).pop();
    await onChanged();
  }

  Future<void> _rename() async {
    final t = AppLocalizations.of(context);
    final title = await showTaqaTextValueDialog(
      context: context,
      title: t.translate('diet_rename_meal_dialog_title'),
      initialValue: widget.event.title,
      keyboardType: TextInputType.text,
    );
    if (!mounted || title == null || title.trim().isEmpty) return;
    final userId = await _userId();
    if (!mounted || userId == null) return;
    await _run(() async {
      if (_isPlanned) {
        await DayTimelineService.updateMealPlan(
          userId: userId,
          planId: _planId,
          title: title.trim(),
          items: _planItems(_items),
        );
      } else {
        await DietService.updateMeal(
          userId: userId,
          mealId: _mealId,
          title: title.trim(),
          date: widget.mealDate,
        );
      }
      await _finish();
    });
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final t = AppLocalizations.of(context);
    final itemId = _int(item['id']);
    if (itemId <= 0) return;
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: t.translate('diet_delete_item_title'),
      message: t
          .translate('diet_delete_item_confirm')
          .replaceAll('{item}', item['name']?.toString() ?? ''),
      confirmLabel: t.translate('diet_delete_item_confirm_button'),
      cancelLabel: t.translate('common_cancel'),
    );
    if (!mounted || !confirmed) return;
    final userId = await _userId();
    if (!mounted || userId == null) return;
    await _run(() async {
      if (_isPlanned) {
        final remaining = [..._items]
          ..removeWhere((candidate) => _int(candidate['id']) == itemId);
        if (remaining.isEmpty) {
          await DayTimelineService.deleteMealPlan(
            userId: userId,
            planId: _planId,
          );
        } else {
          await DayTimelineService.updateMealPlan(
            userId: userId,
            planId: _planId,
            title: widget.event.title,
            items: _planItems(remaining),
          );
        }
      } else {
        await DietService.deleteMealItem(
          userId: userId,
          mealId: _mealId,
          mealItemId: itemId,
          date: widget.mealDate,
        );
      }
      await _finish();
    });
  }

  Future<void> _deleteMeal() async {
    final t = AppLocalizations.of(context);
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: t.translate('diet_delete_meal_title'),
      message: t
          .translate(
            _items.isEmpty
                ? 'diet_delete_meal_confirm_empty'
                : 'diet_delete_meal_confirm_has_items',
          )
          .replaceAll('{meal}', widget.event.title),
      confirmLabel: t.translate('diet_delete_meal_confirm'),
      cancelLabel: t.translate('common_cancel'),
    );
    if (!mounted || !confirmed) return;
    final userId = await _userId();
    if (!mounted || userId == null) return;
    await _run(() async {
      if (_isPlanned) {
        await DayTimelineService.deleteMealPlan(
          userId: userId,
          planId: _planId,
        );
      } else {
        await DietService.deleteMeal(
          userId: userId,
          mealId: _mealId,
          date: widget.mealDate,
        );
      }
      await _finish();
    });
  }

  Future<void> _addItem() async {
    final userId = await _userId();
    if (!mounted || userId == null) return;
    final t = AppLocalizations.of(context);
    final mode = await showTaqaOptionDialog<_CalendarMealEntryMode>(
      context: context,
      title: t.translate('diet_add_item_title'),
      cancelLabel: t.translate('common_cancel'),
      options: [
        TaqaDialogOption(
          value: _CalendarMealEntryMode.search,
          title: t.translate('diet_option_search'),
          subtitle: t.translate('diet_option_search_desc'),
        ),
        TaqaDialogOption(
          value: _CalendarMealEntryMode.manual,
          title: t.translate('diet_option_manual'),
          subtitle: t.translate('diet_option_manual_desc'),
        ),
        TaqaDialogOption(
          value: _CalendarMealEntryMode.photo,
          title: t.translate('diet_option_photo'),
          subtitle: t.translate('diet_option_photo_desc'),
        ),
      ],
    );
    if (!mounted || mode == null) return;
    switch (mode) {
      case _CalendarMealEntryMode.search:
        await _openSearch(userId);
      case _CalendarMealEntryMode.manual:
        await _openManual(userId);
      case _CalendarMealEntryMode.photo:
        await _openPhoto(userId);
    }
  }

  Future<void> _openSearch(int userId) async {
    if (!mounted) return;
    Map<String, dynamic>? picked;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.taqaColors.background,
      builder: (_) => DietItemSearchSheet(
        rootContext: context,
        userId: userId,
        mealId: _mealId,
        mealTitle: widget.event.title,
        onLogged: (_) async => _finish(),
        onPickForManualEntry: _isPlanned
            ? (ingredient) => picked = ingredient
            : null,
      ),
    );
    if (!mounted || !_isPlanned || picked == null) return;
    await _run(() async {
      await _appendPlanItems(userId, [_searchPlanItem(picked!)]);
      await _finish();
    });
  }

  Future<void> _openManual(int userId) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.taqaColors.background,
      builder: (_) => DietManualEntrySheet(
        rootContext: context,
        userId: userId,
        mealId: _mealId,
        mealTitle: widget.event.title,
        mealDate: widget.mealDate,
        onSubmit: _isPlanned
            ? ({required mealName, required ingredients}) async {
                await _appendPlanItems(
                  userId,
                  ingredients.map(_manualPlanItem).toList(),
                );
                return {'status': 'planned'};
              }
            : null,
        successMessage: _isPlanned
            ? (_) => AppLocalizations.of(
                context,
              ).translate('day_timeline_meal_planned')
            : null,
        onLogged: (_) async => _finish(),
      ),
    );
  }

  Future<void> _openPhoto(int userId) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.taqaColors.background,
      builder: (_) => DietPhotoEntrySheet(
        rootContext: context,
        userId: userId,
        mealId: _mealId,
        mealTitle: widget.event.title,
        onSubmit: _isPlanned
            ? ({
                required photoBytes,
                required filename,
                required textDescription,
              }) => DayTimelineService.appendPhotoToMealPlan(
                userId: userId,
                planId: _planId,
                photoBytes: photoBytes,
                filename: filename,
                textDescription: textDescription,
              )
            : null,
        successMessage: _isPlanned
            ? (_) => AppLocalizations.of(
                context,
              ).translate('day_timeline_meal_planned')
            : null,
        onLogged: (_) async => _finish(),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _appendPlanItems(
    int userId,
    List<Map<String, dynamic>> additions,
  ) async {
    await DayTimelineService.updateMealPlan(
      userId: userId,
      planId: _planId,
      title: widget.event.title,
      items: [..._planItems(_items), ...additions],
    );
  }

  List<Map<String, dynamic>> _planItems(List<Map<String, dynamic>> items) =>
      items
          .map(
            (item) => {
              'name': item['name']?.toString() ?? '',
              'grams': item['grams'],
              'calories': _int(item['calories']),
              'protein_g': _int(item['protein_g']),
              'carbs_g': _int(item['carbs_g']),
              'fat_g': _int(item['fat_g']),
              if (item['food_id'] != null) 'food_id': item['food_id'],
              'source': item['source']?.toString() ?? 'manual',
              'is_estimated': item['is_estimated'] == true,
              if (item['photo_url'] != null) 'photo_url': item['photo_url'],
            },
          )
          .toList();

  Map<String, dynamic> _searchPlanItem(Map<String, dynamic> item) => {
    'name': item['name']?.toString() ?? '',
    'grams': item['grams'],
    'calories': _int(item['calories']),
    'protein_g': _int(item['protein']),
    'carbs_g': _int(item['carbs']),
    'fat_g': _int(item['fat']),
    if (item['food_id'] != null) 'food_id': item['food_id'],
    'source': 'search',
  };

  Map<String, dynamic> _manualPlanItem(Map<String, dynamic> item) => {
    'name': item['ingredient_name']?.toString() ?? '',
    'grams': item['grams'],
    'calories': _int(item['calories']),
    'protein_g': _int(item['protein_g']),
    'carbs_g': _int(item['carbs_g']),
    'fat_g': _int(item['fat_g']),
    if (item['food_id'] != null) 'food_id': item['food_id'],
    'source': 'manual',
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: TaqaUiScale.insetsLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.event.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: TaqaUiScale.sp(20),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _working ? null : _rename,
                  icon: Icon(Icons.edit_outlined, color: colors.textPrimary),
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(10)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: TaqaUiScale.h(320)),
              child: ListView(
                shrinkWrap: true,
                children: _items
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name']?.toString() ?? ''),
                        subtitle: Text(
                          '${_int(item['calories'])} kcal · '
                          'P ${_int(item['protein_g'])}g · '
                          'C ${_int(item['carbs_g'])}g · '
                          'F ${_int(item['fat_g'])}g',
                        ),
                        trailing: IconButton(
                          onPressed: _working ? null : () => _deleteItem(item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaFilledButton(
              label: t.translate('diet_add_item_tag'),
              onTap: _working ? null : _addItem,
              loading: _working,
            ),
            TaqaTextActionButton(
              label: t.translate('diet_delete_meal'),
              onTap: _working ? null : _deleteMeal,
              icon: Icons.delete_outline,
              foregroundColor: colors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

int _int(Object? value) =>
    value is num ? value.round() : int.tryParse(value?.toString() ?? '') ?? 0;

enum _CalendarMealEntryMode { search, manual, photo }
