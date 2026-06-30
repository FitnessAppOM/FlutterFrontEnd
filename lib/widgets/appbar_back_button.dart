import 'package:flutter/material.dart';

class AppBarBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AppBarBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return IconButton(
      icon: Icon(isRtl ? Icons.arrow_forward : Icons.arrow_back),
      onPressed: onTap,
    );
  }
}