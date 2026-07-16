import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../styles/taqa_ui_scale.dart';

/// Single-line text that scrolls left-right when it doesn't fit the
/// available width, instead of shrinking (which changes the line height and
/// can throw off layouts tuned around a fixed font size) or wrapping.
class TaqaMarqueeText extends StatelessWidget {
  const TaqaMarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: double.infinity);

        // Small tolerance so sub-pixel rounding between this measurement and
        // the real Text's layout never trips overflow for text that should
        // otherwise fit exactly.
        if (painter.width <= constraints.maxWidth + 0.5) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          );
        }

        return _OscillatingMarqueeText(text: text, style: style, textAlign: textAlign);
      },
    );
  }
}

/// A ticker provider that isn't tied to any single widget's lifecycle, so
/// every [TaqaMarqueeText] instance across the whole app can share one
/// [AnimationController] and stay in lockstep — a per-widget controller
/// would start counting from whenever *that* widget first built, so two
/// otherwise-identical marquees would drift out of phase with each other.
class _AlwaysTickerProvider implements TickerProvider {
  const _AlwaysTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) =>
      Ticker(onTick, debugLabel: 'TaqaMarqueeText.sharedClock');
}

/// Shared clock every marquee instance reads from, so they all start at the
/// same point and turn around at the same instant.
class _MarqueeClock {
  _MarqueeClock._();

  static final AnimationController controller =
      AnimationController(
          vsync: const _AlwaysTickerProvider(),
          duration: const Duration(milliseconds: 6000),
        )
        ..repeat(reverse: true);
}

class _OscillatingMarqueeText extends StatelessWidget {
  const _OscillatingMarqueeText({
    required this.text,
    required this.style,
    required this.textAlign,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: double.infinity);
        // Allow a small trailing buffer for glyph overhang, so the final
        // characters are fully visible when a long name reaches the end.
        final trailingBuffer = TaqaUiScale.w(4);
        final overflow = math.max(
          0.0,
          painter.width + trailingBuffer - constraints.maxWidth,
        );

        if (overflow <= 0) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          );
        }

        return SizedBox(
          height: painter.height,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _MarqueeClock.controller,
              builder: (context, child) {
                return Transform.translate(
                  // Begin with the start of the text visible, then move left
                  // to reveal the rest through to its final glyph — driven by
                  // the shared clock so every instance moves together.
                  offset: Offset(
                    -overflow * _MarqueeClock.controller.value,
                    0,
                  ),
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
                    text,
                    maxLines: 1,
                    softWrap: false,
                    style: style,
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
