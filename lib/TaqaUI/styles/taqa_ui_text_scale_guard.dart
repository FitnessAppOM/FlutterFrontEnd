import 'package:flutter/material.dart';

class TaqaUiTextScaleGuard extends StatelessWidget {
  const TaqaUiTextScaleGuard({
    super.key,
    required this.child,
    this.minScaleFactor = 1.0,
    this.maxScaleFactor = 1.15,
  });

  final Widget child;
  final double minScaleFactor;
  final double maxScaleFactor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedTextScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: minScaleFactor,
      maxScaleFactor: maxScaleFactor,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedTextScaler),
      child: child,
    );
  }
}
