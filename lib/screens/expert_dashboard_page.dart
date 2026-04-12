import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

class ExpertDashboardPage extends StatelessWidget {
  const ExpertDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate('expert_dashboard_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ExpertCard(
            title: t.translate('expert_dash_sec_clients'),
            body: t.translate('expert_dash_sec_clients_body'),
          ),
          _ExpertCard(
            title: t.translate('expert_dash_sec_analytics'),
            body: t.translate('expert_dash_sec_analytics_body'),
          ),
          _ExpertCard(
            title: t.translate('expert_dash_sec_workflow'),
            body: t.translate('expert_dash_sec_workflow_body'),
          ),
        ],
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
