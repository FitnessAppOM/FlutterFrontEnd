import 'package:flutter/material.dart';

import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaRecordDot extends StatelessWidget {
  const TaqaRecordDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TaqaUiStyles.recordDotSize,
      height: TaqaUiStyles.recordDotSize,
      decoration: const BoxDecoration(
        color: TaqaUiColors.recordRed,
        shape: BoxShape.circle,
      ),
    );
  }
}
