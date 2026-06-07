import 'package:flutter/material.dart';

import 'taqa_ui_scale.dart';

class TaqaUiLayout {
  TaqaUiLayout._();

  static double get innerHorizontal => TaqaUiScale.w(30);

  static EdgeInsets get introCardContentPadding =>
      TaqaUiScale.insetsLTRB(30, 15, 30, 15);

  static EdgeInsets get carouselContentPadding =>
      TaqaUiScale.insetsLTRB(30, 12, 30, 12);

  static EdgeInsets get dailyOutlookContentPadding =>
      TaqaUiScale.insetsLTRB(30, 12, 30, 15);
}
