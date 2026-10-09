import 'package:flutter/material.dart';

import '../../TaqaUI/taqa_ui_colors.dart';

Future<int?> showHeightPickerPopup(
  BuildContext context, {
  required int initialHeight,
}) {
  const int minHeight = 120;
  const int maxHeight = 240;
  int currentHeight = initialHeight;
  if (currentHeight < minHeight) currentHeight = minHeight;
  if (currentHeight > maxHeight) currentHeight = maxHeight;

  final sheet = showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.taqaColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) {
      final colors = context.taqaColors;
      return StatefulBuilder(
        builder: (context, setState) {
          void updateFromSlider(double v) {
            final next = v.toInt();
            setState(() => currentHeight = next);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Select Your Height",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 10),

                // --- BODY IMAGE WITH ANIMATION ---
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 250),
                  tween: Tween(
                    begin: currentHeight.toDouble(),
                    end: currentHeight.toDouble(),
                  ),
                  builder: (context, value, _) {
                    return Image.asset(
                      "assets/images/BodyHeight.png",
                      height: value * 1.2, // scaling factor
                      fit: BoxFit.contain,
                    );
                  },
                ),

                const SizedBox(height: 20),

                Text(
                  "$currentHeight cm",
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        final next = (currentHeight - 1).clamp(
                          minHeight,
                          maxHeight,
                        );
                        setState(() => currentHeight = next);
                      },
                      icon: Icon(Icons.remove, color: colors.textPrimary),
                    ),
                    Expanded(
                      child: Slider(
                        value: currentHeight.toDouble(),
                        min: minHeight.toDouble(),
                        max: maxHeight.toDouble(),
                        divisions: maxHeight - minHeight,
                        onChanged: updateFromSlider,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final next = (currentHeight + 1).clamp(
                          minHeight,
                          maxHeight,
                        );
                        setState(() => currentHeight = next);
                      },
                      icon: Icon(Icons.add, color: colors.textPrimary),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // --- CONFIRM BUTTON ---
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, currentHeight),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    minimumSize: const Size.fromHeight(45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Confirm"),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );

  return sheet;
}
