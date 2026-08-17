import 'package:flutter/material.dart';

/// Shared immediate press feedback for TaqaUI controls whose painted
/// background would otherwise hide a Material ink ripple.
class TaqaPressable extends StatefulWidget {
  const TaqaPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.behavior = HitTestBehavior.opaque,
    this.pressedScale = 0.985,
    this.pressedOpacity = 0.82,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;
  final double pressedScale;
  final double pressedOpacity;
  final String? semanticLabel;

  @override
  State<TaqaPressable> createState() => _TaqaPressableState();
}

class _TaqaPressableState extends State<TaqaPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant TaqaPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: widget.behavior,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? widget.pressedScale : 1,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _pressed ? widget.pressedOpacity : 1,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
