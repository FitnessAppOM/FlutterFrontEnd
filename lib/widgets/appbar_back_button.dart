import 'package:flutter/material.dart';

class AppBarBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AppBarBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onTap,
    );
  }
}