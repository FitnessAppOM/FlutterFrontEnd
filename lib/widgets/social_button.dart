import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class SocialButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? iconAsset;

  /// If true, this button is only shown on iOS; otherwise it renders nothing.
  final bool onlyIOS;

  const SocialButton._({
    required this.text,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.onlyIOS = false,
  });

  factory SocialButton.dark({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    String? iconAsset,
  }) {
    return SocialButton._(
      text: text,
      onPressed: onPressed,
      icon: icon,
      iconAsset: iconAsset,
    );
  }

  /// Convenience factory for Apple-style button that only shows on iOS.
  factory SocialButton.apple({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    String? iconAsset,
  }) {
    return SocialButton._(
      text: text,
      onPressed: onPressed,
      icon: icon,
      iconAsset: iconAsset,
      onlyIOS: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely if this is an iOS-only button and we're not on iOS.
    if (onlyIOS && defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return Material(
      color: TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: TaqaUiScale.h(48),
          decoration: BoxDecoration(
            borderRadius: TaqaUiScale.radius(5),
            border: Border.all(
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconAsset != null)
                Padding(
                  padding: EdgeInsets.only(right: TaqaUiScale.w(10)),
                  child: Image.asset(
                    iconAsset!,
                    width: TaqaUiScale.w(20),
                    height: TaqaUiScale.h(20),
                  ),
                )
              else if (icon != null)
                Padding(
                  padding: EdgeInsets.only(right: TaqaUiScale.w(10)),
                  child: Icon(
                    icon,
                    size: TaqaUiScale.w(20),
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              Text(
                text,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(13),
                  fontWeight: FontWeight.w600,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
