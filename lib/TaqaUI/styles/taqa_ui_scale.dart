import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TaqaUiScale {
  TaqaUiScale._();

  static const Size designSize = Size(390, 844);

  static double w(num value) => value.w;
  static double h(num value) => value.h;
  static double r(num value) => value.r;
  static double sp(num value) => value.sp;

  static EdgeInsets insetsLTRB(num left, num top, num right, num bottom) {
    return EdgeInsets.fromLTRB(left.w, top.h, right.w, bottom.h);
  }

  static EdgeInsets symmetric({num horizontal = 0, num vertical = 0}) {
    return EdgeInsets.symmetric(
      horizontal: horizontal.w,
      vertical: vertical.h,
    );
  }

  static BorderRadius radius(num value) => BorderRadius.circular(value.r);
}
