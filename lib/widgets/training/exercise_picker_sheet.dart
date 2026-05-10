import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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
    backgroundColor: AppColors.cardDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      final viewInsets = MediaQuery.of(sheetContext).viewInsets;
      final screenHeight = MediaQuery.of(sheetContext).size.height;
      final availableHeight = screenHeight - viewInsets.bottom;
      final pickerHeight = (availableHeight * 0.56).clamp(260.0, 520.0);
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final normalizedQuery = query.trim().toLowerCase();
          final filtered = normalizedQuery.isEmpty
              ? options
              : options
                    .where(
                      (item) => item.name.toLowerCase().contains(normalizedQuery),
                    )
                    .toList(growable: false);
          return SafeArea(
            top: false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(sheetContext).unfocus(),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                child: SizedBox(
                  height: pickerHeight,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 4, 2),
                        child: Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () {
                                FocusScope.of(sheetContext).unfocus();
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Search exercise',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setSheetState(() => query = value),
                          onSubmitted: (_) =>
                              FocusScope.of(sheetContext).unfocus(),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No exercises found.',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              )
                            : ListView.builder(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  final isSelected = selectedId == option.id;
                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: AppColors.accent.withValues(
                                      alpha: 0.14,
                                    ),
                                    title: Text(
                                      option.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: AppColors.accent,
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(option),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
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
