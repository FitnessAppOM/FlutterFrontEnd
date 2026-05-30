import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

Future<int?> showTaqaValueDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
}) async {
  final text = await _showTaqaInputDialog(
    context: context,
    title: title,
    initialValue: initialValue,
    keyboardType: TextInputType.number,
  );
  if (text == null) return null;
  final parsed = int.tryParse(text.trim());
  if (parsed == null || parsed < 0) return null;
  return parsed;
}

Future<String?> showTaqaTextValueDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  TextInputType keyboardType = TextInputType.number,
}) {
  return _showTaqaInputDialog(
    context: context,
    title: title,
    initialValue: initialValue,
    keyboardType: keyboardType,
  );
}

Future<String?> _showTaqaInputDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required TextInputType keyboardType,
}) async {
  final controller = TextEditingController(text: initialValue);
  final focusNode = FocusNode();
  var hasEdited = initialValue.trim().isNotEmpty;

  try {
    return await showDialog<String>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: Center(
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 390),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: TaqaUiColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: TaqaUiColors.unnamedColor1c1d17.withValues(
                          alpha: 0.08,
                        ),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE4E93B,
                                ).withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: TaqaUiColors.unnamedColor1c1d17,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: TaqaUiColors.unnamedColor1c1d17.withValues(
                                alpha: focusNode.hasFocus ? 0.35 : 0.12,
                              ),
                            ),
                          ),
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            keyboardType: keyboardType,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            onTap: () {
                              controller.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: controller.text.length,
                              );
                              if (!hasEdited) {
                                setLocalState(() => hasEdited = true);
                              }
                            },
                            onChanged: (_) {
                              if (!hasEdited) {
                                setLocalState(() => hasEdited = true);
                              }
                            },
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: hasEdited
                                  ? TaqaUiColors.unnamedColor1c1d17
                                  : TaqaUiColors.unnamedColor1c1d17.withValues(
                                      alpha: 0.35,
                                    ),
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: "0",
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  side: BorderSide(
                                    color: TaqaUiColors.unnamedColor1c1d17
                                        .withValues(alpha: 0.25),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "CANCEL",
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, controller.text.trim()),
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(44),
                                  backgroundColor:
                                      TaqaUiColors.unnamedColorE4e93b,
                                  foregroundColor:
                                      TaqaUiColors.unnamedColor1c1d17,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "SAVE",
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
              ),
            );
          },
        );
      },
    );
  } finally {
    focusNode.dispose();
    controller.dispose();
  }
}
