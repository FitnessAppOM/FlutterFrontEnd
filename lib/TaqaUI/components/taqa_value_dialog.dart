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

class TaqaDialogOption<T> {
  const TaqaDialogOption({
    required this.value,
    required this.title,
    this.subtitle,
  });

  final T value;
  final String title;
  final String? subtitle;
}

Future<T?> showTaqaOptionDialog<T>({
  required BuildContext context,
  required String title,
  required List<TaqaDialogOption<T>> options,
  String? cancelLabel,
}) {
  return showDialog<T>(
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
                  SizedBox(height: TaqaUiScale.h(16)),
                  for (final option in options)
                    Padding(
                      padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                      child: InkWell(
                        borderRadius: TaqaUiScale.radius(15),
                        onTap: () => Navigator.pop(ctx, option.value),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: TaqaUiScale.radius(15),
                            border: Border.all(
                              color: TaqaUiColors.unnamedColor1c1d17.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ),
                          padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(15),
                                  fontWeight: FontWeight.w700,
                                  height: 25 / 15,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                              if (option.subtitle != null &&
                                  option.subtitle!.trim().isNotEmpty) ...[
                                SizedBox(height: TaqaUiScale.h(4)),
                                Text(
                                  option.subtitle!,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(13),
                                    fontWeight: FontWeight.w400,
                                    height: 18 / 13,
                                    letterSpacing: 0,
                                    color: TaqaUiColors.unnamedColor1c1d17
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(6)),
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
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<int?> showTaqaValueDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  String? unit,
  String confirmLabel = "SAVE",
}) async {
  final text = await _showTaqaInputDialog(
    context: context,
    title: title,
    initialValue: initialValue,
    keyboardType: TextInputType.number,
    unit: unit,
    confirmLabel: confirmLabel,
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
  String? unit,
  String confirmLabel = "SAVE",
}) {
  return _showTaqaInputDialog(
    context: context,
    title: title,
    initialValue: initialValue,
    keyboardType: keyboardType,
    unit: unit,
    confirmLabel: confirmLabel,
  );
}

Future<String?> _showTaqaInputDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required TextInputType keyboardType,
  String? unit,
  String confirmLabel = "SAVE",
}) async {
  final controller = TextEditingController(text: initialValue);
  final focusNode = FocusNode();
  var hasEdited = initialValue.trim().isNotEmpty;

  try {
    return await showDialog<String>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) {
        return StatefulBuilder(
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IntrinsicWidth(
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
                              if (unit != null && unit.trim().isNotEmpty) ...[
                                SizedBox(width: TaqaUiScale.w(4)),
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: TaqaUiScale.h(6),
                                  ),
                                  child: Text(
                                    unit,
                                    style: TextStyle(
                                      fontFamily:
                                          TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(15),
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                                  onTap: () => Navigator.pop(
                                    ctx,
                                    controller.text.trim(),
                                  ),
                                  child: SizedBox(
                                    width: TaqaUiScale.w(159),
                                    height: TaqaUiScale.h(45),
                                    child: Center(
                                      child: Text(
                                        confirmLabel,
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
        );
      },
    );
  } finally {
    focusNode.dispose();
    controller.dispose();
  }
}
