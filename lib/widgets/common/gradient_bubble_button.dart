import 'package:flutter/material.dart';

class GradientBubbleButton extends StatelessWidget {
  const GradientBubbleButton({
    super.key,
    this.icon,
    this.child,
    required this.gradient,
    required this.onTap,
    this.size = 64,
    this.borderColor,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final Gradient gradient;
  final VoidCallback? onTap;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: child ??
                Icon(
                  icon,
                  color: Colors.white,
                  size: size * 0.42,
                ),
          ),
        ),
      ),
    );
  }
}
