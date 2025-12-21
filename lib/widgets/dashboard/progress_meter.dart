import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProgressMeter extends StatefulWidget {
  const ProgressMeter({
    super.key,
    required this.title,
    required this.progress,
    this.targetLabel,
    this.accentColor = AppColors.accent,
    this.trailingLabel,
    this.onTap,
  });

  final String title;
  final double progress; // 0..1
  final String? targetLabel;
  final Color accentColor;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  State<ProgressMeter> createState() => _ProgressMeterState();
}

class _ProgressMeterState extends State<ProgressMeter> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  void _handleTapDown(TapDownDetails _) => _setPressed(true);
  void _handleTapCancel() => _setPressed(false);
  void _handleTap() {
    _setPressed(false);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = widget.progress.clamp(0.0, 1.0);
    final edgeColor = const Color(0xFFD4AF37).withValues(alpha: 0.18);

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap == null ? null : _handleTap,
          onTapDown: widget.onTap == null ? null : _handleTapDown,
          onTapCancel: _handleTapCancel,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: edgeColor),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${(clamped * 100).round()}%",
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.trailingLabel != null)
                          Text(
                            widget.trailingLabel!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: clamped,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                  ),
                ),
                if (widget.targetLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.targetLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
