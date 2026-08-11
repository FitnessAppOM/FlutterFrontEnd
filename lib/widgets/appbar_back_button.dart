import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_back_button.dart';

class AppBarBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AppBarBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TaqaBackButton(onPressed: onTap);
  }
}
