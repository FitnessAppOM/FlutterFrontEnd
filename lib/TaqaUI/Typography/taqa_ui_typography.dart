import 'package:flutter/material.dart';

class TaqaUiFontFamilies {
  TaqaUiFontFamilies._();

  static const String interTight = 'InterTight';
  static const String iaWriterMonoS = 'IAWriterMonoS';
}

class TaqaUiTypography {
  TaqaUiTypography._();

  static const TextStyle mono = TextStyle(
    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
    fontWeight: FontWeight.w400,
  );
}
