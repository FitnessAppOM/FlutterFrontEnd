import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import 'taqa_expert_client_dashboard_ui.dart';
import 'taqa_expert_dashboard_ui.dart';
import 'taqa_profile_info_section.dart';

class TaqaExpertClientView extends StatelessWidget {
  const TaqaExpertClientView({
    super.key,
    required this.name,
    required this.userId,
    required this.activityStatus,
    required this.personalInfoItems,
    required this.habitsTotal,
    required this.habitsChecked,
    required this.habitsEnabled,
    required this.onOpenSupportChat,
    required this.onOpenAnalytics,
    required this.onOpenTrainingPlan,
    required this.onOpenHabits,
    required this.onOpenDietReview,
    required this.onOpenAiUpdates,
    this.avatarUrl,
    this.habitsError,
    this.analyticsAlert,
    this.trainingPlanAlert,
    this.dietAlert,
    this.supportChatAlert,
    this.aiUpdatesAlert,
    this.trainingPlanLoading = false,
  });

  final String name;
  final int userId;
  final String? avatarUrl;
  final String? activityStatus;
  final List<TaqaProfileInfoItem> personalInfoItems;
  final int habitsTotal;
  final int habitsChecked;
  final bool habitsEnabled;
  final String? habitsError;
  final String? analyticsAlert;
  final String? trainingPlanAlert;
  final String? dietAlert;
  final String? supportChatAlert;
  final String? aiUpdatesAlert;
  final bool trainingPlanLoading;
  final VoidCallback onOpenSupportChat;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenTrainingPlan;
  final VoidCallback onOpenHabits;
  final VoidCallback onOpenDietReview;
  final VoidCallback onOpenAiUpdates;

  @override
  Widget build(BuildContext context) {
    final habitsDescription =
        habitsError ??
        (habitsTotal == 0
            ? 'No habits set yet.'
            : 'Review client habit completion.');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: TaqaUiScale.insetsLTRB(16, 0, 17, 24),
      children: [
        TaqaExpertClientCard(
          name: name,
          avatarUrl: avatarUrl,
          status: activityStatus,
          subtitle: 'User ID: $userId',
          alerts: const [],
        ),
        _gap(),
        TaqaProfileInfoSection(
          title: 'Personal Information',
          items: personalInfoItems,
        ),
        _gap(),
        TaqaClientDashboardNavigationCard(
          title: 'Support Chat',
          description:
              'Open chat thread with this client and send text replies.',
          noticeText: supportChatAlert,
          onTap: onOpenSupportChat,
        ),
        _gap(),
        TaqaClientDashboardNavigationCard(
          title: 'Analytics',
          description: 'Open client analytics and activity status.',
          noticeText: analyticsAlert,
          onTap: onOpenAnalytics,
        ),
        _gap(),
        TaqaClientDashboardNavigationCard(
          title: 'Habits',
          description: habitsDescription,
          onTap: habitsEnabled ? onOpenHabits : null,
          content: habitsTotal == 0
              ? null
              : Column(
                  children: [
                    TaqaClientDashboardInfoRow(
                      label: 'Total habits',
                      value: '$habitsTotal',
                    ),
                    SizedBox(height: TaqaUiScale.h(6)),
                    TaqaClientDashboardInfoRow(
                      label: 'Checked this week',
                      value: '$habitsChecked',
                    ),
                  ],
                ),
        ),
        _gap(),
        TaqaClientDashboardNavigationCard(
          title: 'Diet Review',
          description:
              'View this client diet logs by date and leave coach comments.',
          noticeText: dietAlert,
          onTap: onOpenDietReview,
        ),
        _gap(),
        TaqaClientDashboardNavigationCard(
          title: 'AI Updates',
          description: 'Open AI-driven form feedback and training suggestions.',
          statusText: aiUpdatesAlert,
          onTap: onOpenAiUpdates,
        ),
        SizedBox(height: TaqaUiScale.h(24)),
      ],
    );
  }

  Widget _gap() => SizedBox(height: TaqaUiScale.h(12));
}
