import 'package:flutter/material.dart';

import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coach/coach_feedback_panel.dart';
import '../widgets/coach/coach_info_panel.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  String? _assignedCoachName;
  bool _profileLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileLoaded) return;
    _profileLoaded = true;
    _loadAssignedCoachName();
  }

  Future<void> _loadAssignedCoachName() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) return;
      if (!mounted) return;
      final lang = AppLocalizations.of(context).locale.languageCode;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final raw = (profile["assigned_expert_name"] ?? "").toString().trim();
      if (!mounted) return;
      setState(() {
        _assignedCoachName = raw.isEmpty ? null : raw;
      });
    } catch (_) {
      // Keep page usable when coach assignment is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Expert Page'),
              if ((_assignedCoachName ?? '').isNotEmpty)
                Text(
                  _assignedCoachName!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
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
