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

    return LayoutBuilder(
      builder: (context, constraints) {
        final namePainter = TextPainter(
          text: TextSpan(text: userName, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        final shouldSplit = namePainter.width > constraints.maxWidth;

        if (!shouldSplit) {
          return Text(
            '$greeting $userName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: style,
          );
        }

        final greetingStyle = style.copyWith(
          fontSize: (style.fontSize ?? 25) * 0.82,
          height: 1,
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: greetingStyle,
            ),
            SizedBox(height: TaqaUiScale.h(4)),
            Expanded(
              child: _OscillatingNameText(text: userName, style: style),
            ),
          ],
        );
      },
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
    duration: const Duration(milliseconds: 2800),
  );

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
        final overflow = math.max(0.0, painter.width - constraints.maxWidth);

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

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-overflow * _controller.value, 0),
                child: child,
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                style: widget.style,
              ),
            ),
          ),
        );
      },
    );
  }
}
