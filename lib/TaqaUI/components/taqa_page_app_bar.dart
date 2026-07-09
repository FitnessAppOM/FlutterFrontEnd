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
    this.bottom,
    this.titleColor = TaqaUiColors.unnamedColor1c1d17,
  });

  final String title;
  final Color backgroundColor;
  final Widget? leading;
  final Widget? trailing;
  final bool showBackButton;
  final Color titleColor;

  /// Optional extra row (e.g. a [TabBar]) rendered below the title, inside
  /// the same app bar surface. Adds its preferred height on top of the
  /// standard 94-tall header.
  final PreferredSizeWidget? bottom;

  static const double _height = 60;

  @override
  Size get preferredSize => Size.fromHeight(
    TaqaUiScale.h(_height) + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: TaqaUiScale.h(_height),
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: bottom,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (showBackButton)
              Positioned(
                top: TaqaUiScale.h(8),
                left: TaqaUiScale.w(8),
                child: leading ?? const TaqaBackButton(),
              ),
            Positioned(
              top: TaqaUiScale.h(12),
              left: TaqaUiScale.w(16),
              child: TaqaPageHeader(title: title, color: titleColor),
            ),
            if (trailing != null)
              Positioned(
                top: TaqaUiScale.h(8),
                right: TaqaUiScale.w(8),
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
