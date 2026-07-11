import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Floating "CHAT" pill — a 62x62 white square with three rounded corners
/// and one sharp corner (bottom-right), giving it a speech-bubble tail.
/// Matches the Figma spec: 62x62, radius 31/31/0/31, shadow
/// 0px 0px 30px #00000029, "CHAT" label in iA Writer Mono S 12px uppercase.
class TaqaFloatingChatButton extends StatelessWidget {
  const TaqaFloatingChatButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = TaqaUiScale.w(62);
    final radius = TaqaUiScale.r(31);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
        ),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
              bottomRight: Radius.zero,
              bottomLeft: Radius.circular(radius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: TaqaUiScale.r(30),
              ),
            ],
          ),
          child: Text(
            "CHAT",
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(12),
              height: 14 / 12,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
        ),
      ),
    );
  }
}
