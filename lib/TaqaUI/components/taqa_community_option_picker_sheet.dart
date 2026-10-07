import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Reusable theme-aware TaqaUI sheet for choosing one text option.
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
    final colors = context.taqaColors;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Container(
          padding: TaqaUiScale.insetsLTRB(16, 10, 16, 24),
          decoration: BoxDecoration(
            color: colors.background,
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
                    color: colors.textSecondary.withValues(alpha: 0.45),
                    borderRadius: TaqaUiScale.radius(99),
                  ),
                ),
              ),
              SizedBox(height: TaqaUiScale.h(18)),
              Text(
                taqaUppercase(title),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: TaqaUiScale.sp(10),
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: options
                      .map((option) {
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
                                      ? colors.accent
                                      : colors.surface,
                                  borderRadius: TaqaUiScale.radius(5),
                                  border: Border.all(
                                    color: selected
                                        ? colors.onAccent.withValues(
                                            alpha: 0.35,
                                          )
                                        : colors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        taqaUppercase(
                                          option.replaceAll('_', ' '),
                                        ),
                                        style: TextStyle(
                                          fontFamily:
                                              TaqaUiFontFamilies.interTight,
                                          fontSize: TaqaUiScale.sp(14),
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? colors.onAccent
                                              : colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check,
                                        size: TaqaUiScale.w(18),
                                        color: colors.onAccent,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
