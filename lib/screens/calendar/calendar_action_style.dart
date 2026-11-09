import 'package:flutter/material.dart';

/// Calendar actions sit on plain surfaces, so their labels need a neutral
/// foreground instead of the app's yellow button-text accent.
ButtonStyle calendarActionStyle(BuildContext context) {
  final foreground = Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? foreground.withValues(alpha: 0.38)
          : foreground,
    ),
  );
}
