import 'package:flutter/material.dart';

/// Shared immediate press feedback for TaqaUI controls whose painted
/// background would otherwise hide a Material ink ripple.
class TaqaPressable extends StatefulWidget {
  const TaqaPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.behavior = HitTestBehavior.opaque,
    this.pressedScale = 0.975,
    this.pressedOpacity = 0.62,
    this.minimumFeedbackDuration = const Duration(milliseconds: 90),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;
  final double pressedScale;
  final double pressedOpacity;
  final Duration minimumFeedbackDuration;
  final String? semanticLabel;

  @override
  State<TaqaPressable> createState() => _TaqaPressableState();
}

class _TaqaPressableState extends State<TaqaPressable> {
  bool _pressed = false;
  bool _activating = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  void _handleTapDown(TapDownDetails details) {
    if (_activating) return;
    _setPressed(true);
  }

  void _handleTapCancel() {
    _setPressed(false);
  }

  Future<void> _handleTap() async {
    final callback = widget.onTap;
    if (callback == null || _activating) return;
    _activating = true;

    if (!_pressed) _setPressed(true);
    // Keep the feedback visible after finger-up. Measuring from tap-down can
    // make a normal tap clear the state in the same frame navigation starts.
    await Future<void>.delayed(widget.minimumFeedbackDuration);
    if (!mounted) return;

    setState(() {
      _pressed = false;
      _activating = false;
    });
    callback();
  }

  @override
  void didUpdateWidget(covariant TaqaPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) {
      _pressed = false;
      _activating = false;
    }
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
          onTapDown: enabled ? _handleTapDown : null,
          onTapCancel: enabled ? _handleTapCancel : null,
          onTap: enabled ? _handleTap : null,
          child: AnimatedScale(
            scale: _pressed ? widget.pressedScale : 1,
            duration: const Duration(milliseconds: 55),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _pressed ? widget.pressedOpacity : 1,
              duration: const Duration(milliseconds: 55),
              curve: Curves.easeOut,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
