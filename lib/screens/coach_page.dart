import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/coach/coach_feedback_panel.dart';
import '../widgets/coach/coach_info_panel.dart';

class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          title: Text(t.translate('coach_page_title')),
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: t.translate('coach_tab_feedback')),
              Tab(text: t.translate('coach_tab_chat')),
              Tab(text: t.translate('coach_tab_form_check')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const CoachFeedbackPanel(),
            CoachInfoPanel(
              title: t.translate('coach_tab_chat'),
              icon: Icons.chat_bubble_outline,
              bullets: [
                t.translate('coach_chat_b1'),
                t.translate('coach_chat_b2'),
                t.translate('coach_chat_b3'),
              ],
            ),
            CoachInfoPanel(
              title: t.translate('coach_tab_form_check'),
              icon: Icons.smart_toy_outlined,
              bullets: [
                t.translate('coach_form_check_b1'),
                t.translate('coach_form_check_b2'),
                t.translate('coach_form_check_b3'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
