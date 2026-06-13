import 'package:flutter/material.dart';

import '../../TaqaUI/styles/taqa_ui_scale.dart';

class DateSwitcher extends StatelessWidget {
  const DateSwitcher({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
    this.labelStyle,
    this.iconColor = Colors.white70,
    this.labelWidth,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final bool canGoNext;
  final TextStyle? labelStyle;
  final Color iconColor;
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveLabelWidth = labelWidth ?? TaqaUiScale.w(62);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: labelStyle ??
          const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onPrev,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TaqaUiScale.w(10),
              vertical: TaqaUiScale.h(8),
            ),
            child: SizedBox(
              width: TaqaUiScale.w(2),
              height: TaqaUiScale.h(2),
              child: CustomPaint(
                painter: _TinyArrowPainter(color: iconColor, pointRight: false),
              ),
            ),
          ),
        ),
        SizedBox(width: TaqaUiScale.w(12)),
        SizedBox(width: effectiveLabelWidth, child: text),
        SizedBox(width: TaqaUiScale.w(12)),
        GestureDetector(
          onTap: canGoNext ? onNext : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TaqaUiScale.w(10),
              vertical: TaqaUiScale.h(8),
            ),
            child: SizedBox(
              width: TaqaUiScale.w(2),
              height: TaqaUiScale.h(2),
              child: CustomPaint(
                painter: _TinyArrowPainter(
                  color: canGoNext
                      ? iconColor
                      : iconColor.withValues(alpha: 0.3),
                  pointRight: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TinyArrowPainter extends CustomPainter {
  const _TinyArrowPainter({required this.color, required this.pointRight});

  final Color color;
  final bool pointRight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final path = pointRight
        ? (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height))
        : (Path()
          ..moveTo(size.width, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TinyArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointRight != pointRight;
}
