import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaProfileInfoItem {
  const TaqaProfileInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class TaqaProfileInfoSection extends StatelessWidget {
  const TaqaProfileInfoSection({super.key, required this.items, this.title});

  final List<TaqaProfileInfoItem> items;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').trim().isNotEmpty)
            Padding(
              padding: TaqaUiScale.symmetric(vertical: 5),
              child: Text(
                title!,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w700,
                  height: 25 / 15,
                  letterSpacing: 0,
                  color: TaqaUiColors.charcoal,
                ),
              ),
            ),
          ...items.map(
            (item) => TaqaProfileInfoRow(label: item.label, value: item.value),
          ),
        ],
      ),
    );
  }
}

class TaqaProfileInfoRow extends StatelessWidget {
  const TaqaProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

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
      color: TaqaUiColors.charcoal,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
