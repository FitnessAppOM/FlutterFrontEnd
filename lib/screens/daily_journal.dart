import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/navigation_service.dart';
import '../main/main_layout.dart';

class DailyJournalPage extends StatelessWidget {
  const DailyJournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Journal'),
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
            Text(
              'Journal placeholder',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 6),
            Text(
              'Tap notifications to land here.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
