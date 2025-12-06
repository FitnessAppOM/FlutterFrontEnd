import 'package:flutter/material.dart';

class FadePageTransition extends PageRouteBuilder {
  final Widget page;

  FadePageTransition({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}