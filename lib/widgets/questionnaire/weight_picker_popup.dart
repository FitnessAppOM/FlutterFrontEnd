import 'package:flutter/material.dart';

Future<int?> showWeightPickerPopup(
    BuildContext context, {
      required int initialWeight,
    }) {
  int currentWeight = initialWeight;

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
                  "Select Your Weight",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 15),

                // -------------------------
                // 3-ZONE BODY STRETCH (only the middle widens)
                // -------------------------
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 250),
                  tween: Tween<double>(
                    begin: currentWeight.toDouble(),
                    end: currentWeight.toDouble(),
                  ),
                  builder: (_, value, __) {
                    // Map weight 50–150 → scale 0.90–2.0
                    double normalized =
                    ((value - 50) / (150 - 50)).clamp(0.0, 1.0);
                    final centerScale =
                        0.90 + (normalized * (2.0 - 0.90)); // smooth middle stretch

                    return SizedBox(
                      height: 250,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // LEFT part (unchanged)
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.33,
                              child: Image.asset(
                                "assets/images/BodyHeight.png",
                                height: 250,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // CENTER part (stretches horizontally)
                          Transform.scale(
                            scaleX: centerScale,
                            scaleY: 1.0,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.center,
                                widthFactor: 0.34,
                                child: Image.asset(
                                  "assets/images/BodyHeight.png",
                                  height: 250,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),

                          // RIGHT part (unchanged)
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerRight,
                              widthFactor: 0.33,
                              child: Image.asset(
                                "assets/images/BodyHeight.png",
                                height: 250,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                Text(
                  "$currentWeight kg",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                Slider(
                  value: currentWeight.toDouble(),
                  min: 30,
                  max: 200,
                  divisions: 170,
                  label: "$currentWeight kg",
                  onChanged: (v) {
                    setState(() => currentWeight = v.toInt());
                  },
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: () => Navigator.pop(context, currentWeight),
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
