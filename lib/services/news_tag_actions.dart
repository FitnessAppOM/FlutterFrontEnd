import 'package:flutter/material.dart';
import 'navigation_service.dart';
import '../screens/settings_page.dart';

class NewsTagActions {
  static const Set<String> _journalTags = {
    'journal',
    'journal reminder',
    'daily journal',
  };

  static const Set<String> _applyTags = {
    'apply',
    'application',
  };

  static bool handleTagTap(BuildContext context, String tag) {
    final normalized = tag.toLowerCase().trim();

    if (_journalTags.contains(normalized)) {
      NavigationService.navigateToJournal(fromNotification: false);
      return true;
    }

    if (_applyTags.contains(normalized)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      return true;
    }

    // No-op for other tags (default behavior).
    return false;
  }
}
