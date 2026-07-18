import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../core/account_storage.dart';
import '../main/main_layout.dart';
import '../widgets/coach/coach_chat_panel.dart';

/// Coach-side support chat. Shares [CoachChatPanel] with the client-side
/// chat page (lib/screens/coach_page.dart) — same UI and behavior, the only
/// difference is which side of the conversation this account is on.
class ExpertClientChatPage extends StatelessWidget {
  const ExpertClientChatPage({
    super.key,
    required this.clientUserId,
    required this.clientName,
    this.clientAvatarUrl,
    this.clientActivityStatus,
  });

  final int clientUserId;
  final String clientName;
  final String? clientAvatarUrl;
  final String? clientActivityStatus;

  Future<void> _handleBackPressed(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final isExpert = await AccountStorage.isExpert();
    if (!context.mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isExpert
            ? const MainLayout(
                initialIndex: MainLayout.coachTabIndex,
                autoOpenExpertDashboard: true,
              )
            : const MainLayout(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: 'Support Chat',
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        titleColor: TaqaUiColors.charcoal,
        leading: IconButton(
          onPressed: () => _handleBackPressed(context),
          icon: Icon(
            canPop ? Icons.arrow_back : Icons.close,
            color: TaqaUiColors.charcoal,
          ),
          tooltip: canPop ? 'Back' : 'Close',
        ),
      ),
      body: SafeArea(
        child: CoachChatPanel.forCoach(
          clientUserId: clientUserId,
          clientName: clientName,
          clientAvatarUrl: clientAvatarUrl,
          clientActivityStatus: clientActivityStatus,
        ),
      ),
    );
  }
}
