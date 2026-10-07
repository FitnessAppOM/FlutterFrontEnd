import 'dart:async';

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_popup_guard.dart';
import 'taqa_pressable.dart';

class TaqaSearchablePickerField extends StatelessWidget {
  const TaqaSearchablePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.itemLabelBuilder,
    required this.onChanged,
    required this.searchHint,
    required this.noResultsText,
    required this.closeLabel,
    this.hint = 'Select',
    this.enabled = true,
    this.validator,
    this.pinnedValues = const <String>{},
  });

  final String label;
  final String? value;
  final List<String> options;
  final String Function(String) itemLabelBuilder;
  final ValueChanged<String?>? onChanged;
  final String searchHint;
  final String noResultsText;
  final String closeLabel;
  final String hint;
  final bool enabled;
  final String? Function(String?)? validator;
  final Set<String> pinnedValues;

  Future<void> _openPicker(
    BuildContext context,
    FormFieldState<String> field,
  ) async {
    if (!enabled || options.isEmpty) return;
    final selected = await showTaqaSearchablePickerSheet(
      context: context,
      title: label,
      searchHint: searchHint,
      noResultsText: noResultsText,
      closeLabel: closeLabel,
      options: options,
      selectedValue: value,
      itemLabelBuilder: itemLabelBuilder,
      pinnedValues: pinnedValues,
    );
    if (selected == null) return;
    field.didChange(selected);
    onChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final textStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(14),
      fontWeight: FontWeight.w500,
      color: colors.textPrimary,
    );
    final selectedLabel = value == null ? null : itemLabelBuilder(value!);

    return FormField<String>(
      key: ValueKey<String?>(value),
      initialValue: value,
      validator: validator,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: TaqaUiScale.h(4)),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(11),
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => _openPicker(context, field) : null,
              child: Container(
                constraints: BoxConstraints(minHeight: TaqaUiScale.h(36)),
                padding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(6)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: field.hasError ? colors.danger : colors.border,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLabel ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.copyWith(
                          color: selectedLabel == null
                              ? colors.textSecondary.withValues(
                                  alpha: enabled ? 1 : 0.45,
                                )
                              : colors.textPrimary.withValues(
                                  alpha: enabled ? 1 : 0.45,
                                ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: colors.textSecondary.withValues(
                        alpha: enabled ? 0.5 : 0.22,
                      ),
                      size: TaqaUiScale.w(20),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (field.errorText != null)
            Padding(
              padding: EdgeInsets.only(top: TaqaUiScale.h(4)),
              child: Text(
                field.errorText!,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(10),
                  color: colors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<String?> showTaqaSearchablePickerSheet({
  required BuildContext context,
  required String title,
  required String searchHint,
  required String noResultsText,
  required String closeLabel,
  required List<String> options,
  required String Function(String) itemLabelBuilder,
  String? selectedValue,
  Set<String> pinnedValues = const <String>{},
}) async {
  if (options.isEmpty) return null;
  final searchController = TextEditingController();
  Timer? debounce;
  var query = '';

  final selected = await TaqaPopupGuard.bottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.taqaColors.scrim,
    builder: (sheetContext) {
      final colors = sheetContext.taqaColors;
      final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
      final availableHeight =
          MediaQuery.sizeOf(sheetContext).height - viewInsets.bottom;
      final pickerHeight = (availableHeight * 0.62)
          .clamp(TaqaUiScale.h(300), TaqaUiScale.h(560))
          .toDouble();

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final normalizedQuery = _normalizeSearch(query);
          final filtered = normalizedQuery.isEmpty
              ? options
              : options
                    .where(
                      (option) =>
                          pinnedValues.contains(option) ||
                          _normalizeSearch(
                            itemLabelBuilder(option),
                          ).contains(normalizedQuery),
                    )
                    .toList(growable: false);

          return SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Container(
                height: pickerHeight,
                padding: TaqaUiScale.insetsLTRB(16, 10, 17, 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(TaqaUiScale.r(15)),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: TaqaUiScale.w(36),
                      height: TaqaUiScale.h(3),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.45),
                        borderRadius: TaqaUiScale.radius(2),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(9)),
                    SizedBox(
                      height: TaqaUiScale.h(25),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontWeight: FontWeight.w700,
                                fontSize: TaqaUiScale.sp(15),
                                height: 25 / 15,
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            end: 0,
                            child: TaqaPressable(
                              onTap: () => Navigator.of(sheetContext).pop(),
                              pressedScale: 0.82,
                              semanticLabel: closeLabel,
                              child: Icon(
                                Icons.close,
                                color: colors.textPrimary,
                                size: TaqaUiScale.w(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(10)),
                    SizedBox(
                      height: TaqaUiScale.h(39),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        cursorColor: colors.accent,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(15),
                          height: 21 / 15,
                        ),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: TextStyle(
                            color: colors.textSecondary,
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: colors.textSecondary,
                            size: TaqaUiScale.w(18),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: colors.border,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: colors.accent,
                              width: 0.5,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          debounce?.cancel();
                          if (_normalizeSearch(value).isEmpty) {
                            setSheetState(() => query = '');
                            return;
                          }
                          debounce = Timer(
                            const Duration(milliseconds: 250),
                            () {
                              if (sheetContext.mounted) {
                                setSheetState(() => query = value);
                              }
                            },
                          );
                        },
                        onSubmitted: (_) =>
                            FocusScope.of(sheetContext).unfocus(),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                noResultsText,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(15),
                                ),
                              ),
                            )
                          : ListView.separated(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => Divider(
                                height: TaqaUiScale.h(1),
                                color: colors.divider,
                              ),
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final isSelected = selectedValue == option;
                                return Material(
                                  color: isSelected
                                      ? colors.accent.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                  borderRadius: TaqaUiScale.radius(5),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: TaqaUiScale.symmetric(
                                      horizontal: 10,
                                    ),
                                    title: Text(
                                      itemLabelBuilder(option),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: TaqaUiScale.sp(15),
                                        height: 18 / 15,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: colors.textPrimary,
                                            size: TaqaUiScale.w(16),
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(option),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  debounce?.cancel();
  searchController.dispose();
  return selected;
}

String _normalizeSearch(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
