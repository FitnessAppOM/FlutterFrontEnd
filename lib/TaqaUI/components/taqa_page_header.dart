import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaPageHeader extends StatelessWidget {
  const TaqaPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TaqaUiScale.w(357),
      height: TaqaUiScale.h(39),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 2.5,
          letterSpacing: 0,
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
      ),
    );
  }
}
