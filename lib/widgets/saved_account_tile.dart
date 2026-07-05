import 'package:flutter/material.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class SavedAccountTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  const SavedAccountTile({
    super.key,
    required this.title,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(15),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(15),
        onTap: onTap,
        child: Padding(
          padding: TaqaUiScale.insetsLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: TaqaUiScale.w(36),
                height: TaqaUiScale.h(36),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: TaqaUiColors.unnamedColorE4e93b,
                ),
                child: Icon(
                  Icons.person,
                  color: TaqaUiColors.unnamedColor1c1d17,
                  size: TaqaUiScale.w(18),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(13),
                    fontWeight: FontWeight.w600,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.4),
                  size: TaqaUiScale.w(20),
                ),
                onPressed: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
