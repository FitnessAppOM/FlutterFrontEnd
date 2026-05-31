import 'package:flutter/material.dart';
import '../Typography/taqa_ui_typography.dart';

class TaqaSheetActionButton extends StatelessWidget {
  const TaqaSheetActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.height = 58,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? const Color(0xFF191C16) : Colors.white;
    final fg = filled ? Colors.white : const Color(0xFF1C1D17);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class TaqaSegmentTabButton extends StatelessWidget {
  const TaqaSegmentTabButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: active ? const Color(0xFFDDE530) : Colors.white,
          foregroundColor: const Color(0xFF1C1D17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          side: active
              ? BorderSide.none
              : BorderSide(
                  color: const Color(0xFF1C1D17).withValues(alpha: 0.12),
                ),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1D17),
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

Future<bool> showTaqaActionConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF45474A),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        cancelLabel.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFDDE530),
                        foregroundColor: const Color(0xFF1C1D17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        confirmLabel.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1D17),
                        ),
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
  return result == true;
}
