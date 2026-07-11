import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';

/// One metric shown in a [TaqaCardioStatPanel] (e.g. Time, Distance, Pace,
/// Steps). [accent] highlights the value in the panel's lime-yellow accent
/// color — used for the "hero" metric (usually Time).
class TaqaCardioStatMetric {
  const TaqaCardioStatMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;
}

/// Dark, rounded metrics strip used to show live/summary cardio stats
/// (Time / Distance / Pace / Steps) — shared between the live map cardio
/// controls and the post-workout cardio achievement card so both read as
/// one design: big bold value over a small muted label, separated by thin
/// dividers instead of individually boxed pills.
class TaqaCardioStatPanel extends StatelessWidget {
  const TaqaCardioStatPanel({super.key, required this.metrics});

  final List<TaqaCardioStatMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D20),
        borderRadius: TaqaUiScale.radius(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            _Readout(metric: metrics[i]),
            if (i != metrics.length - 1) const _Divider(),
          ],
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.metric});

  final TaqaCardioStatMetric metric;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: metric.accent ? const Color(0xFFFFE033) : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(16),
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(3)),
          Text(
            metric.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: TaqaUiScale.sp(10),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: TaqaUiScale.h(28),
      margin: TaqaUiScale.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
