import 'dart:async';
import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

enum AppToastType { info, success, error }

enum AppToastPosition { top, bottom }

class AppToast {
  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    AppToastPosition position = AppToastPosition.bottom,
    bool rootOverlay = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context, rootOverlay: rootOverlay);

    final accentColor = switch (type) {
      AppToastType.success => TaqaUiColors.unnamedColorE4e93b,
      AppToastType.error => TaqaUiColors.unnamedColorE93b3b,
      _ => TaqaUiColors.unnamedColor1c1d17,
    };

    final iconColor = switch (type) {
      AppToastType.success => TaqaUiColors.unnamedColor1c1d17,
      _ => TaqaUiColors.white,
    };

    final icon = switch (type) {
      AppToastType.success => Icons.check_rounded,
      AppToastType.error => Icons.priority_high_rounded,
      _ => Icons.info_outline,
    };

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        accentColor: accentColor,
        iconColor: iconColor,
        icon: icon,
        position: position,
        duration: duration,
        onDismiss: () {
          if (entry != null && entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.accentColor,
    required this.iconColor,
    required this.icon,
    required this.position,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final Color accentColor;
  final Color iconColor;
  final IconData icon;
  final AppToastPosition position;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _offset = Tween<Offset>(
      begin: Offset(0, widget.position == AppToastPosition.top ? -0.16 : 0.16),
      end: Offset.zero,
    ).animate(curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);

    _controller.forward();
    _timer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top + TaqaUiScale.h(16);
    final bottomInset = mediaQuery.padding.bottom + TaqaUiScale.h(16);
    return Positioned(
      left: TaqaUiScale.w(16),
      right: TaqaUiScale.w(16),
      top: widget.position == AppToastPosition.top ? topInset : null,
      bottom: widget.position == AppToastPosition.bottom ? bottomInset : null,
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiScale.radius(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: TaqaUiScale.w(24),
                    height: TaqaUiScale.h(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: TaqaUiScale.w(14),
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(10)),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w600,
                        height: 18 / 13,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
