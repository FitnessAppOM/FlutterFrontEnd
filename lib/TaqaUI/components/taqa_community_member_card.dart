import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityMemberAction {
  const TaqaCommunityMemberAction({required this.id, required this.label});

  final String id;
  final String label;
}

class TaqaCommunityMemberCard extends StatelessWidget {
  const TaqaCommunityMemberCard({
    super.key,
    required this.name,
    required this.role,
    required this.status,
    this.avatarUrl,
    this.actions = const [],
    this.onActionTap,
  });

  final String name;
  final String role;
  final String status;
  final String? avatarUrl;
  final List<TaqaCommunityMemberAction> actions;
  final ValueChanged<String>? onActionTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      padding: TaqaUiScale.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: TaqaUiScale.r(18),
                backgroundColor: TaqaUiColors.charcoal.withValues(alpha: 0.08),
                backgroundImage: avatarUrl == null
                    ? null
                    : NetworkImage(avatarUrl!),
                child: avatarUrl == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontWeight: FontWeight.w800,
                          color: TaqaUiColors.charcoal,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(16),
                        fontWeight: FontWeight.w800,
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(4)),
                    Text(
                      '${role.toUpperCase()} · ${status.toUpperCase()}',
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                        fontSize: TaqaUiScale.sp(8),
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(14)),
            Wrap(
              spacing: TaqaUiScale.w(8),
              runSpacing: TaqaUiScale.h(8),
              children: actions
                  .map(
                    (action) => _MemberActionButton(
                      action: action,
                      onTap: onActionTap == null
                          ? null
                          : () => onActionTap!(action.id),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberActionButton extends StatelessWidget {
  const _MemberActionButton({required this.action, this.onTap});

  final TaqaCommunityMemberAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(5),
        child: Container(
          height: TaqaUiScale.h(32),
          padding: TaqaUiScale.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: TaqaUiColors.charcoal, width: 0.5),
            borderRadius: TaqaUiScale.radius(5),
          ),
          child: Text(
            action.label.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.charcoal,
            ),
          ),
        ),
      ),
    );
  }
}
