import 'package:flutter/material.dart';

class DateSwitcher extends StatelessWidget {
  const DateSwitcher({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
    this.labelStyle,
    this.iconColor = Colors.white70,
    this.labelWidth,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final bool canGoNext;
  final TextStyle? labelStyle;
  final Color iconColor;
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style:
          labelStyle ??
          const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: iconColor),
          onPressed: onPrev,
        ),
        if (labelWidth != null)
          SizedBox(width: labelWidth, child: text)
        else
          text,
        IconButton(
          icon: Icon(Icons.chevron_right, color: iconColor),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}
