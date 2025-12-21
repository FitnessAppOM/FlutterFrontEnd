import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/navigation_service.dart';
import '../main/main_layout.dart';
import '../localization/app_localizations.dart';

class DailyJournalPage extends StatelessWidget {
  const DailyJournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    return Scaffold(
      appBar: AppBar(
        title: Text(t("journal_title")),
        automaticallyImplyLeading: true,
        leading: NavigationService.launchedFromNotificationPayload
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // When opened from a notification (cold start), ensure back goes to dashboard.
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainLayout()),
                    (route) => false,
                  );
                },
              )
            : null,
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit_note, size: 64, color: Colors.white),
            SizedBox(height: 12),
            _JournalText(),
            SizedBox(height: 6),
            _JournalHint(),
          ],
        ),
      ),
    );
  }
}

class _JournalText extends StatelessWidget {
  const _JournalText();
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    return Text(
      t("journal_placeholder"),
      style: const TextStyle(color: Colors.white, fontSize: 18),
    );
  }
}

class _JournalHint extends StatelessWidget {
  const _JournalHint();
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    return Text(
      t("journal_hint"),
      style: const TextStyle(color: Colors.white70),
    );
  }
}
