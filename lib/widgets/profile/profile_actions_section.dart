import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';

class ProfileActionsSection extends StatelessWidget {
  const ProfileActionsSection({
    super.key,
    required this.onEditProfile,
    required this.onLogout,
    this.editEnabled = true,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onLogout;
  final bool editEnabled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(
      children: [
        _ActionButton(
          label: t.translate("edit_profile"),
          backgroundColor: editEnabled
              ? TaqaUiColors.unnamedColorE4e93b
              : TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
          textColor: TaqaUiColors.unnamedColor1c1d17,
          onTap: editEnabled ? onEditProfile : null,
        ),
        SizedBox(height: TaqaUiScale.h(15)),
        _ActionButton(
          label: t.translate("sign_out"),
          backgroundColor: TaqaUiColors.unnamedColor1c1d17,
          textColor: TaqaUiColors.white,
          onTap: onLogout,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(45),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w600,
                height: 12 / 10,
                letterSpacing: 0,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
