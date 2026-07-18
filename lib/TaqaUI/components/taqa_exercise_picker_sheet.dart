import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class ExercisePickerItem {
  const ExercisePickerItem({required this.id, required this.name});

  final int id;
  final String name;
}

Future<ExercisePickerItem?> showExercisePickerSheet({
  required BuildContext context,
  required List<ExercisePickerItem> options,
  int? selectedId,
  String title = 'Select Exercise',
}) async {
  if (options.isEmpty) return null;
  final searchController = TextEditingController();
  String query = '';

  final selected = await showModalBottomSheet<ExercisePickerItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (sheetContext) {
      final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
      final availableHeight =
          MediaQuery.sizeOf(sheetContext).height - viewInsets.bottom;
      final pickerHeight = (availableHeight * 0.62).clamp(
        TaqaUiScale.h(300),
        TaqaUiScale.h(560),
      );

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final normalizedQuery = query.trim().toLowerCase();
          final filtered = normalizedQuery.isEmpty
              ? options
              : options
                    .where(
                      (item) =>
                          item.name.toLowerCase().contains(normalizedQuery),
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
                  color: TaqaUiColors.white,
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
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.25),
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
                                color: TaqaUiColors.charcoal,
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontWeight: FontWeight.w700,
                                fontSize: TaqaUiScale.sp(15),
                                height: 25 / 15,
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            end: 0,
                            child: GestureDetector(
                              onTap: () => Navigator.of(sheetContext).pop(),
                              child: Icon(
                                Icons.close,
                                color: TaqaUiColors.charcoal,
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
                        cursorColor: TaqaUiColors.charcoal,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(
                          color: TaqaUiColors.charcoal,
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(15),
                          height: 21 / 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search exercise',
                          hintStyle: TextStyle(
                            color: TaqaUiColors.charcoal.withValues(alpha: 0.5),
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: TaqaUiColors.charcoal,
                            size: TaqaUiScale.w(18),
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: TaqaUiColors.charcoal,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: TaqaUiColors.charcoal,
                              width: 0.5,
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        onSubmitted: (_) =>
                            FocusScope.of(sheetContext).unfocus(),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No exercises found.',
                                style: TextStyle(
                                  color: TaqaUiColors.charcoal.withValues(
                                    alpha: 0.62,
                                  ),
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
                                color: TaqaUiColors.charcoal.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final option = filtered[index];
                                final isSelected = selectedId == option.id;
                                return Material(
                                  color: isSelected
                                      ? TaqaUiColors.lime.withValues(
                                          alpha: 0.35,
                                        )
                                      : Colors.transparent,
                                  borderRadius: TaqaUiScale.radius(5),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: TaqaUiScale.symmetric(
                                      horizontal: 10,
                                    ),
                                    title: Text(
                                      option.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: TaqaUiColors.charcoal,
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: TaqaUiScale.sp(15),
                                        height: 18 / 15,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: TaqaUiColors.charcoal,
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

  searchController.dispose();
  return selected;
}
