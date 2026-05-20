import 'package:flutter/material.dart';

class TaqaEditModeBubble extends StatelessWidget {
  const TaqaEditModeBubble({
    super.key,
    required this.visible,
    this.onTap,
  });

  final bool visible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.96,
          duration: const Duration(milliseconds: 180),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0x1F000000)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x29000000),
                    blurRadius: 30,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
