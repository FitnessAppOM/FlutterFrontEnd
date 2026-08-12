import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_settings_row_card.dart';

/// A reusable TaqaUI navigation list for community-management actions.
class TaqaCommunityManagementList extends StatelessWidget {
  const TaqaCommunityManagementList({
    super.key,
    required this.groupName,
    required this.onActionTap,
  });

  final String groupName;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final actions = <TaqaCommunityManagementAction>[
      TaqaCommunityManagementAction(
        id: 'edit',
        title: t.translate('community_edit_group'),
        description: t.translate('community_edit_group_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'members',
        title: t.translate('community_manage_members'),
        description: t.translate('community_manage_members_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'view_code',
        title: t.translate('community_view_join_code'),
        description: t.translate('community_view_join_code_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'code',
        title: t.translate('community_reset_join_code'),
        description: t.translate('community_reset_join_code_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'metric',
        title: t.translate('community_leaderboard_metric'),
        description: t.translate('community_leaderboard_metric_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'challenges',
        title: t.translate('community_group_challenges'),
        description: t.translate('community_group_challenges_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'pin',
        title: t.translate('community_pinned_items'),
        description: t.translate('community_pinned_items_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'reports',
        title: t.translate('community_reports'),
        description: t.translate('community_reports_body'),
      ),
      TaqaCommunityManagementAction(
        id: 'archive',
        title: t.translate('community_archive_group'),
        description: t.translate('community_archive_group_body'),
      ),
    ];
    return ListView.separated(
      padding: TaqaUiScale.insetsLTRB(16, 8, 16, 24),
      itemCount: actions.length + 1,
      separatorBuilder: (_, __) => SizedBox(height: TaqaUiScale.h(12)),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: TaqaUiScale.h(4),
              left: TaqaUiScale.w(2),
            ),
            child: Text(
              groupName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(14),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
              ),
            ),
          );
        }
        final action = actions[index - 1];
        return TaqaSettingsRowCard(
          title: action.title,
          description: action.description,
          onTap: () => onActionTap(action.id),
        );
      },
    );
  }
}

class TaqaCommunityManagementAction {
  const TaqaCommunityManagementAction({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}
