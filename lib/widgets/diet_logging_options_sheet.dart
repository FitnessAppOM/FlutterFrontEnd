import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class DietLoggingOptionsSheet extends StatelessWidget {
  const DietLoggingOptionsSheet({
    super.key,
    required this.mealTitle,
    required this.onSearch,
    required this.onManualEntry,
    required this.onPhotoEntry,
  });

  final String mealTitle;
  final VoidCallback onSearch;
  final VoidCallback onManualEntry;
  final VoidCallback onPhotoEntry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: TaqaUiScale.symmetric(horizontal: 17),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.none,
          child: Container(
            constraints: BoxConstraints(maxWidth: TaqaUiScale.w(356)),
            padding: TaqaUiScale.insetsLTRB(13.5, 15, 13.5, 15),
            decoration: BoxDecoration(
              color: TaqaUiColors.white,
              borderRadius: TaqaUiScale.radius(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  t.translate("diet_add_item_title"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w700,
                    height: 25 / 15,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(11)),
                _OptionButton(
                  label: t.translate("diet_option_search"),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSearch();
                  },
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _OptionButton(
                  label: t.translate("diet_option_manual"),
                  onTap: () {
                    Navigator.of(context).pop();
                    onManualEntry();
                  },
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _OptionButton(
                  label: t.translate("diet_option_photo"),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPhotoEntry();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.unnamedColorE4e93b,
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
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w600,
                height: 12 / 10,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
