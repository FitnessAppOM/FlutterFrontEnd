import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Reusable light TaqaUI sheet for choosing one text option.
class TaqaCommunityOptionPickerSheet extends StatelessWidget {
  const TaqaCommunityOptionPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final String title;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: TaqaUiScale.insetsLTRB(16, 10, 16, 24),
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE3e3e3,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TaqaUiScale.r(24)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: TaqaUiScale.w(36),
                height: TaqaUiScale.h(4),
                decoration: BoxDecoration(
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.2),
                  borderRadius: TaqaUiScale.radius(99),
                ),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(18)),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            ...options.map((option) {
              final selected = option == selectedValue;
              return Padding(
                padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(option),
                    borderRadius: TaqaUiScale.radius(5),
                    child: Container(
                      height: TaqaUiScale.h(45),
                      padding: TaqaUiScale.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? TaqaUiColors.accent
                            : TaqaUiColors.white,
                        borderRadius: TaqaUiScale.radius(5),
                        border: Border.all(
                          color: TaqaUiColors.charcoal.withValues(
                            alpha: selected ? 0.35 : 0.08,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: TaqaUiScale.sp(14),
                                fontWeight: FontWeight.w700,
                                color: TaqaUiColors.charcoal,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check,
                              size: TaqaUiScale.w(18),
                              color: TaqaUiColors.charcoal,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
