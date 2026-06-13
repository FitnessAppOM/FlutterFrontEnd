import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

Future<bool> showTaqaConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      return Align(
        alignment: Alignment.center,
        child: Padding(
          padding: TaqaUiScale.symmetric(horizontal: 17),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.none,
            child: Container(
              constraints: BoxConstraints(maxWidth: TaqaUiScale.w(356)),
              padding: TaqaUiScale.insetsLTRB(17, 15, 17, 15),
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiScale.radius(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w400,
                      height: 18 / 13,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(24)),
                  SizedBox(
                    height: TaqaUiScale.h(45),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Center(
                              child: Text(
                                (cancelLabel ?? "CANCEL").toUpperCase(),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(10),
                                  fontWeight: FontWeight.w600,
                                  height: 12 / 10,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: TaqaUiColors.unnamedColorE4e93b,
                          borderRadius: TaqaUiScale.radius(5),
                          child: InkWell(
                            borderRadius: TaqaUiScale.radius(5),
                            onTap: () => Navigator.pop(ctx, true),
                            child: SizedBox(
                              width: TaqaUiScale.w(159),
                              height: TaqaUiScale.h(45),
                              child: Center(
                                child: Text(
                                  confirmLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(10),
                                    fontWeight: FontWeight.w700,
                                    height: 12 / 10,
                                    letterSpacing: 0,
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
  return result == true;
}

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
        return MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              return Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: TaqaUiScale.symmetric(horizontal: 17),
                  child: Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.none,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: TaqaUiScale.w(356)),
                      padding: TaqaUiScale.insetsLTRB(17, 15, 17, 15),
                      decoration: BoxDecoration(
                        color: TaqaUiColors.white,
                        borderRadius: TaqaUiScale.radius(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(15),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(33)),
                          SizedBox(
                            height: TaqaUiScale.h(30),
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
                                fontSize: TaqaUiScale.sp(25),
                                fontWeight: FontWeight.w400,
                                height: 1,
                                letterSpacing: 0,
                                color: hasEdited
                                    ? TaqaUiColors.unnamedColor1c1d17
                                    : TaqaUiColors.unnamedColorE3e3e3,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: "0",
                              ),
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(33)),
                          SizedBox(
                            height: TaqaUiScale.h(45),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Center(
                                      child: Text(
                                        "CANCEL",
                                        style: TextStyle(
                                          fontFamily:
                                              TaqaUiFontFamilies.interTight,
                                          fontSize: TaqaUiScale.sp(10),
                                          fontWeight: FontWeight.w600,
                                          height: 12 / 10,
                                          letterSpacing: 0,
                                          color:
                                              TaqaUiColors.unnamedColor1c1d17,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Material(
                                  color: TaqaUiColors.unnamedColorE4e93b,
                                  borderRadius: TaqaUiScale.radius(5),
                                  child: InkWell(
                                    borderRadius: TaqaUiScale.radius(5),
                                    onTap: () => Navigator.pop(
                                      ctx,
                                      controller.text.trim(),
                                    ),
                                    child: SizedBox(
                                      width: TaqaUiScale.w(159),
                                      height: TaqaUiScale.h(45),
                                      child: Center(
                                        child: Text(
                                          "SAVE",
                                          style: TextStyle(
                                            fontFamily:
                                                TaqaUiFontFamilies.interTight,
                                            fontSize: TaqaUiScale.sp(10),
                                            fontWeight: FontWeight.w700,
                                            height: 12 / 10,
                                            letterSpacing: 0,
                                            color:
                                                TaqaUiColors.unnamedColor1c1d17,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  } finally {
    focusNode.dispose();
    controller.dispose();
  }
}
