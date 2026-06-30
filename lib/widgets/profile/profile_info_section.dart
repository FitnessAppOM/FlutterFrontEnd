import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';

class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({
    super.key,
    required this.age,
    required this.sex,
    required this.height,
    required this.occupation,
    required this.weight,
  });

  final String age;
  final String sex;
  final String height;
  final String occupation;
  final String weight;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: TaqaUiScale.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        children: [
          ProfileInfoRow(label: t.translate("profile_age"), value: age),
          ProfileInfoRow(label: t.translate("profile_sex"), value: sex),
          ProfileInfoRow(label: t.translate("profile_height"), value: height),
          ProfileInfoRow(label: t.translate("profile_weight"), value: weight),
          ProfileInfoRow(
            label: t.translate("profile_occupation"),
            value: occupation,
          ),
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(15),
      fontWeight: FontWeight.w400,
      height: 25 / 15,
      letterSpacing: 0,
      color: TaqaUiColors.unnamedColor1c1d17,
    );

    return Padding(
      padding: TaqaUiScale.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: style),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
