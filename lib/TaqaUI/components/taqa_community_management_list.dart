import 'package:flutter/material.dart';

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

  static const List<TaqaCommunityManagementAction> _actions = [
    TaqaCommunityManagementAction(
      id: 'edit',
      title: 'Edit group',
      description: 'Update the name, description, visibility, and category.',
    ),
    TaqaCommunityManagementAction(
      id: 'members',
      title: 'Manage members',
      description: 'Review members and update their roles.',
    ),
    TaqaCommunityManagementAction(
      id: 'view_code',
      title: 'View join code',
      description: 'Show the current private invite code.',
    ),
    TaqaCommunityManagementAction(
      id: 'code',
      title: 'Reset join code',
      description: 'Invalidate the old code and create a new one.',
    ),
    TaqaCommunityManagementAction(
      id: 'metric',
      title: 'Leaderboard metric',
      description: 'Choose what your group leaderboard measures.',
    ),
    TaqaCommunityManagementAction(
      id: 'challenges',
      title: 'Group challenges',
      description: 'Create and manage challenges for this group.',
    ),
    TaqaCommunityManagementAction(
      id: 'pin',
      title: 'Pinned items',
      description: 'Manage important tips, rules, and announcements.',
    ),
    TaqaCommunityManagementAction(
      id: 'reports',
      title: 'Reports',
      description: 'Review reported posts and comments.',
    ),
    TaqaCommunityManagementAction(
      id: 'archive',
      title: 'Archive group',
      description: 'Permanently archive this community.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: TaqaUiScale.insetsLTRB(16, 8, 16, 24),
      itemCount: _actions.length + 1,
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
        final action = _actions[index - 1];
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
