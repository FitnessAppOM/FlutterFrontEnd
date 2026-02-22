import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor = AppColors.accent,
    this.borderColor,
    this.borderWidth = 1,
    this.deltaPercent,
    this.footerLeft,
    this.footerRight,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color accentColor;
  final Color? borderColor;
  final double borderWidth;
  final int? deltaPercent;
  final Widget? footerLeft;
  final Widget? footerRight;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
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

  void _handleLongPress() {
    _setPressed(false);
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edgeColor = (widget.borderColor ?? const Color(0xFFD4AF37))
        .withValues(alpha: widget.borderColor == null ? 0.18 : 1);
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleTap,
          onLongPress: widget.onLongPress == null ? null : _handleLongPress,
          onTapDown: _handleTapDown,
          onTapCancel: _handleTapCancel,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: edgeColor, width: widget.borderWidth),
            ),
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon ?? Icons.insights, color: widget.accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.value,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.footerRight != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: widget.footerRight!,
                  )
                else if (widget.deltaPercent != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        Icon(
                          widget.deltaPercent! >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12,
                          color: widget.deltaPercent! >= 0
                              ? const Color(0xFF4CD964)
                              : const Color(0xFFFF8A00),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${widget.deltaPercent!.abs()}%",
                          style: TextStyle(
                            color: widget.deltaPercent! >= 0
                                ? const Color(0xFF4CD964)
                                : const Color(0xFFFF8A00),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.footerLeft != null)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: widget.footerLeft!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
