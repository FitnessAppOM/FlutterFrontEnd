import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Shared log-entry card design used by history-style lists (training
/// process logs, training plan logs, cardio history, ...) so they all stay
/// pixel-identical instead of drifting via separately hand-copied widgets.
class TaqaLogEntryCard extends StatelessWidget {
  const TaqaLogEntryCard({
    super.key,
    required this.title,
    required this.badgeText,
    required this.subtitle,
    this.detailWidgets = const [],
    this.onTap,
    this.badge,
  });

  final String title;
  final String badgeText;
  final String subtitle;
  final List<Widget> detailWidgets;
  final VoidCallback? onTap;

  /// Overrides the plain [badgeText] rendering with a custom widget (e.g. a
  /// bordered [TaqaOutlineTagButton]) when the corner marker needs to look
  /// like an actual tag rather than bare text.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w700,
                    height: 25 / 15,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ),
              if (badge != null)
                badge!
              else if (badgeText.isNotEmpty)
                Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                    fontSize: TaqaUiScale.sp(8),
                    fontWeight: FontWeight.w400,
                    height: 10 / 8,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(19)),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 21 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          if (detailWidgets.isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(8)),
            ...detailWidgets,
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: TaqaUiScale.radius(15),
              onTap: onTap,
              child: card,
            ),
    );
  }
}
