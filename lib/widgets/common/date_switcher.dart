import 'package:flutter/material.dart';

class DateSwitcher extends StatelessWidget {
  const DateSwitcher({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white70),
          onPressed: onPrev,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white70),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}
