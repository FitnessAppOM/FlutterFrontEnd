import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityGroupPickerOption {
  const TaqaCommunityGroupPickerOption({
    required this.id,
    required this.name,
    required this.memberCount,
    this.description,
  });

  final int id;
  final String name;
  final int memberCount;
  final String? description;
}

/// Light TaqaUI sheet for selecting the group used by the Community feed.
class TaqaCommunityGroupPickerSheet extends StatelessWidget {
  const TaqaCommunityGroupPickerSheet({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TaqaCommunityGroupPickerOption> options;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: TaqaUiScale.h(600)),
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
              'CHOOSE A GROUP',
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: TaqaUiScale.h(10)),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option.id == selectedId;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelected(option.id),
                      borderRadius: TaqaUiScale.radius(15),
                      child: Container(
                        padding: TaqaUiScale.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? TaqaUiColors.accent
                              : TaqaUiColors.white,
                          borderRadius: TaqaUiScale.radius(15),
                          border: Border.all(
                            color: TaqaUiColors.charcoal.withValues(
                              alpha: selected ? 0.35 : 0.08,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(16),
                                      fontWeight: FontWeight.w800,
                                      color: TaqaUiColors.charcoal,
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(4)),
                                  Text(
                                    '${option.memberCount} MEMBER${option.memberCount == 1 ? '' : 'S'}',
                                    style: TextStyle(
                                      fontFamily:
                                          TaqaUiFontFamilies.iaWriterMonoS,
                                      fontSize: TaqaUiScale.sp(8),
                                      color: TaqaUiColors.charcoal.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: TaqaUiScale.w(12)),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                              size: TaqaUiScale.w(20),
                              color: TaqaUiColors.charcoal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
