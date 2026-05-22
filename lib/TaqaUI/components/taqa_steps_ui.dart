import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

class TaqaRangeTab extends StatelessWidget {
  const TaqaRangeTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? TaqaUiColors.unnamedColorE4e93b : TaqaUiColors.white,
          borderRadius: BorderRadius.circular(5),
          border: selected
              ? null
              : Border.all(
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
                ),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ),
    );
  }
}

class TaqaTagButton extends StatelessWidget {
  const TaqaTagButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = TaqaUiColors.graphite.withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: TaqaUiColors.unnamedColor1c1d17),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                fontSize: 8,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> showTaqaValueDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  var editing = false;
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 17),
          child: Container(
            width: 356,
            height: 190,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: TaqaUiColors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 2.5,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 72,
                  height: 30,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    onTap: () {
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      );
                      if (!editing) {
                        setLocalState(() => editing = true);
                      }
                    },
                    onChanged: (_) {
                      if (!editing) {
                        setLocalState(() => editing = true);
                      }
                    },
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 25,
                      fontWeight: FontWeight.w400,
                      height: 1,
                      letterSpacing: 0,
                      color: editing
                          ? TaqaUiColors.unnamedColor1c1d17
                          : TaqaUiColors.unnamedColorE3e3e3,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    SizedBox(
                      width: 159,
                      height: 45,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TaqaUiColors.unnamedColor1c1d17,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            "CANCEL",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              letterSpacing: 0,
                              color: TaqaUiColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 159,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {
                          final parsed = int.tryParse(controller.text.trim());
                          if (parsed == null || parsed < 0) {
                            Navigator.pop(ctx);
                            return;
                          }
                          Navigator.pop(ctx, parsed);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: TaqaUiColors.unnamedColorE4e93b,
                          foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          "SAVE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<String?> showTaqaTextValueDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  TextInputType keyboardType = TextInputType.number,
}) async {
  final controller = TextEditingController(text: initialValue);
  var editing = false;
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 17),
          child: Container(
            width: 356,
            height: 190,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: TaqaUiColors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 2.5,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 96,
                  height: 30,
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    textAlign: TextAlign.center,
                    onTap: () {
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      );
                      if (!editing) setLocalState(() => editing = true);
                    },
                    onChanged: (_) {
                      if (!editing) setLocalState(() => editing = true);
                    },
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 25,
                      fontWeight: FontWeight.w400,
                      height: 1,
                      letterSpacing: 0,
                      color: editing
                          ? TaqaUiColors.unnamedColor1c1d17
                          : TaqaUiColors.unnamedColorE3e3e3,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    SizedBox(
                      width: 159,
                      height: 45,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TaqaUiColors.unnamedColor1c1d17,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            "CANCEL",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              letterSpacing: 0,
                              color: TaqaUiColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 159,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: TaqaUiColors.unnamedColorE4e93b,
                          foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          "SAVE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
