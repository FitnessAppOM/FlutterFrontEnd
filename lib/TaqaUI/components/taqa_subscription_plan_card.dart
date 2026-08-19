import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// A selectable subscription plan card.
class TaqaSubscriptionPlanCard extends StatelessWidget {
  const TaqaSubscriptionPlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.period,
    this.description,
    this.promotionText,
    this.student = false,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String price;
  final String period;
  final String? description;
  final String? promotionText;
  final bool student;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? TaqaUiColors.accent
        : TaqaUiColors.charcoal.withValues(alpha: 0.12);

    return Material(
      color: TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(15),
        child: Container(
          width: double.infinity,
          padding: TaqaUiScale.insetsLTRB(16, 16, 16, 15),
          decoration: BoxDecoration(
            borderRadius: TaqaUiScale.radius(15),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (student)
                      Container(
                        margin: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
                        padding: TaqaUiScale.insetsLTRB(7, 3, 7, 3),
                        decoration: BoxDecoration(
                          color: TaqaUiColors.accent,
                          borderRadius: TaqaUiScale.radius(5),
                        ),
                        child: Text(
                          'STUDENT',
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                            fontSize: TaqaUiScale.sp(8),
                            fontWeight: FontWeight.w400,
                            color: TaqaUiColors.charcoal,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(17),
                        fontWeight: FontWeight.w700,
                        height: 21 / 17,
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(5)),
                    Text(
                      description ?? '$period subscription',
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(12),
                        fontWeight: FontWeight.w400,
                        height: 16 / 12,
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                      ),
                    ),
                    if (promotionText != null) ...[
                      SizedBox(height: TaqaUiScale.h(6)),
                      Text(
                        promotionText!,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(11),
                          fontWeight: FontWeight.w700,
                          color: TaqaUiColors.charcoal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (selected)
                    Padding(
                      padding: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
                      child: Icon(
                        Icons.check_circle,
                        size: TaqaUiScale.w(18),
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                  Text(
                    price,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(28),
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
