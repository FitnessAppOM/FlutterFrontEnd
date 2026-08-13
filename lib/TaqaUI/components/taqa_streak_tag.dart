import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import 'taqa_outline_tag_button.dart';

class TaqaStreakTag extends StatelessWidget {
  const TaqaStreakTag({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final unit = t(days == 1 ? 'taqa_unit_day' : 'taqa_unit_days');
    return TaqaOutlineTagButton(
      label: '$days $unit',
      width: Localizations.localeOf(context).languageCode == 'ar'
          ? TaqaUiScale.w(62)
          : TaqaUiStyles.streakTagWidth,
    );
  }
}
