import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';

class TaqaAdaptiveNameText extends StatelessWidget {
  const TaqaAdaptiveNameText({
    super.key,
    required this.welcomeText,
    required this.style,
    this.greetingText,
    this.userNameText,
  });

  final String welcomeText;
  final String? greetingText;
  final String? userNameText;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingText?.trim();
    final userName = userNameText?.trim();
    if (userName != null &&
        userName.isNotEmpty &&
        (greeting == null || greeting.isEmpty)) {
      return _OverflowAwareSingleLineText(text: userName, style: style);
    }
    if (greeting == null ||
        greeting.isEmpty ||
        userName == null ||
        userName.isEmpty) {
      return Text(
        welcomeText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        style: style,
      );
    }

    // Keep the greeting fixed and scroll only an overflowing name in the
    // remaining horizontal space.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$greeting ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        Expanded(
          child: _OverflowAwareSingleLineText(text: userName, style: style),
        ),
      ],
    );
  }
}

class _OverflowAwareSingleLineText extends StatelessWidget {
  const _OverflowAwareSingleLineText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        if (painter.width <= constraints.maxWidth) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }

        return _OscillatingNameText(text: text, style: style);
      },
    );
  }
}

class _OscillatingNameText extends StatefulWidget {
  const _OscillatingNameText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_OscillatingNameText> createState() => _OscillatingNameTextState();
}

class _OscillatingNameTextState extends State<_OscillatingNameText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  );

  @override
  void didUpdateWidget(covariant _OscillatingNameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        // Allow a small trailing buffer for glyph overhang, so the final
        // characters are fully visible when a long name reaches the end.
        final trailingBuffer = TaqaUiScale.w(4);
        final overflow = math.max(
          0.0,
          painter.width + trailingBuffer - constraints.maxWidth,
        );

        if (overflow <= 0) {
          _controller.stop();
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
          );
        }

        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }

        return SizedBox(
          height: painter.height,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  // Begin with the start of the name visible, then move left
                  // to reveal the rest of the full name through to its final
                  // glyph.
                  offset: Offset(-overflow * _controller.value, 0),
                  child: child,
                );
              },
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                // Without an explicit height, OverflowBox sizes itself to the
                // incoming constraints rather than its child, which are
                // unbounded here (e.g. a Column placing this without a fixed
                // height) and throws "given infinite size during layout".
                minHeight: painter.height,
                maxHeight: painter.height,
                child: Padding(
                  padding: EdgeInsets.only(right: trailingBuffer),
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    softWrap: false,
                    style: widget.style,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
