import 'package:flutter/material.dart';

import '../styles/taqa_ui_styles.dart';
import 'taqa_outline_tag_button.dart';

class TaqaStreakTag extends StatelessWidget {
  const TaqaStreakTag({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return TaqaOutlineTagButton(
      label: '$days Days',
      width: TaqaUiStyles.streakTagWidth,
    );
  }
}
