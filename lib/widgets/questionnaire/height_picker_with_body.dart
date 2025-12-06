import 'package:flutter/material.dart';

Future<int?> showHeightPickerPopup(
    BuildContext context, {
      required int initialHeight,
    }) {
  int currentHeight = initialHeight;

  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.grey,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),

                // --- BODY IMAGE WITH ANIMATION ---
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 250),
                  tween: Tween(begin: currentHeight.toDouble(), end: currentHeight.toDouble()),
                  builder: (context, value, _) {
                    return Image.asset(
                      "assets/images/BodyHeight.png",
                      height: value * 1.2, // scaling factor
                      fit: BoxFit.contain,
                    );
                  },
                ),

                const SizedBox(height: 20),

                // --- SLIDER ---
                Text(
                  "$currentHeight cm",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: currentHeight.toDouble(),
                  min: 120,
                  max: 240,
                  divisions: 120,
                  label: "$currentHeight",
                  onChanged: (v) =>
                      setState(() => currentHeight = v.toInt()),
                ),

                const SizedBox(height: 8),

                // --- CONFIRM BUTTON ---
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, currentHeight),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
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
}
