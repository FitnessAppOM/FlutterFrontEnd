import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaPageHeader extends StatelessWidget {
  const TaqaPageHeader({
    super.key,
    required this.title,
    this.color = TaqaUiColors.unnamedColor1c1d17,
  });

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TaqaUiScale.w(357),
      height: TaqaUiScale.h(39),
      alignment: Alignment.center,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(15),
          fontWeight: FontWeight.w700,
          height: 25 / 15,
          letterSpacing: 0,
          color: color,
        ),
      ),
    );
  }
}
