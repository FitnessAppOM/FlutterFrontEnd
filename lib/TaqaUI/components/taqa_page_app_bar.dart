import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_back_button.dart';
import 'taqa_page_header.dart';

class TaqaPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TaqaPageAppBar({
    super.key,
    required this.title,
    this.backgroundColor = TaqaUiColors.unnamedColorE3e3e3,
    this.leading,
    this.trailing,
    this.showBackButton = true,
  });

  final String title;
  final Color backgroundColor;
  final Widget? leading;
  final Widget? trailing;
  final bool showBackButton;

  @override
  Size get preferredSize => Size.fromHeight(TaqaUiScale.h(149));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: TaqaUiScale.h(149),
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (showBackButton)
              Positioned(
                top: TaqaUiScale.h(20),
                left: TaqaUiScale.w(8),
                child: leading ?? const TaqaBackButton(),
              ),
            Positioned(
              top: TaqaUiScale.h(94),
              left: TaqaUiScale.w(16),
              child: TaqaPageHeader(title: title),
            ),
            if (trailing != null)
              Positioned(
                top: TaqaUiScale.h(20),
                right: TaqaUiScale.w(8),
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
