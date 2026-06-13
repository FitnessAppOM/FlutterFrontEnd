import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

class TaqaSetRowEditResult {
  const TaqaSetRowEditResult({
    required this.reps,
    required this.rir,
    required this.weightKg,
    required this.completed,
  });

  final int reps;
  final int rir;
  final double weightKg;
  final bool completed;
}

Future<TaqaSetRowEditResult?> showTaqaSetRowEditDialog({
  required BuildContext context,
  required int setIndex,
  required int reps,
  required int rir,
  required double weightKg,
  required bool completed,
}) async {
  final repsCtrl = TextEditingController(text: reps.toString());
  final rirCtrl = TextEditingController(text: rir.toString());
  final weightCtrl = TextEditingController(
    text: weightKg <= 0
        ? ''
        : (weightKg == weightKg.roundToDouble()
              ? weightKg.toStringAsFixed(0)
              : weightKg.toStringAsFixed(1)),
  );
  var done = completed;

  try {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return MediaQuery.removeViewInsets(
              context: ctx,
              removeBottom: true,
              child: Center(
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
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
                        Text(
                          "Set $setIndex",
                          style: const TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                label: "KG",
                                child: TextField(
                                  controller: weightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: TaqaUiColors.unnamedColor1c1d17,
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
                                    hintText: "0",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Field(
                                label: "REPS",
                                child: TextField(
                                  controller: repsCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: TaqaUiColors.unnamedColor1c1d17,
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
                                    hintText: "0",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Field(
                                label: "RIR",
                                child: TextField(
                                  controller: rirCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: TaqaUiColors.unnamedColor1c1d17,
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
                                    hintText: "0",
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => setLocalState(() => done = !done),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: done
                                        ? const Color(0xFFE4E93B)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: done
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color:
                                              TaqaUiColors.unnamedColor1c1d17,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Completed",
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
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
                                onPressed: () => Navigator.of(ctx).pop(true),
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

    if (saved != true) return null;

    final parsedReps = int.tryParse(repsCtrl.text.trim());
    final parsedRir = int.tryParse(rirCtrl.text.trim());
    final parsedWeight = double.tryParse(weightCtrl.text.trim());

    return TaqaSetRowEditResult(
      reps: (parsedReps ?? reps).clamp(1, 200),
      rir: (parsedRir ?? rir).clamp(0, 10),
      weightKg: weightCtrl.text.trim().isEmpty ? 0 : (parsedWeight ?? weightKg),
      completed: done,
    );
  } finally {
    repsCtrl.dispose();
    rirCtrl.dispose();
    weightCtrl.dispose();
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: 10,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
