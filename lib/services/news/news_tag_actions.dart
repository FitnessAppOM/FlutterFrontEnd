import 'package:flutter/material.dart';
import '../core/navigation_service.dart';
import '../../screens/settings_page.dart';
import '../../screens/article_page.dart';
import '../../models/news_item.dart';
import '../../auth/expert_questionnaire.dart';
import '../../core/account_storage.dart';
import '../../widgets/app_toast.dart';
import '../../localization/app_localizations.dart';
import '../auth/profile_service.dart';

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

  static bool handleTagTap(BuildContext context, String tag, {NewsItem? item}) {
    final normalized = tag.toLowerCase().trim();

    if (_journalTags.contains(normalized)) {
      NavigationService.navigateToJournal(fromNotification: false);
      return true;
    }

    if (_applyTags.contains(normalized)) {
      _navigateToExpertQuestionnaire(context);
      return true;
    }

    if (normalized == "article") {
      if (item == null) return false;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArticlePage(item: item)),
      );
      return true;
    }

    // No-op for other tags (default behavior).
    return false;
  }
}

Future<void> _navigateToExpertQuestionnaire(BuildContext context) async {
  final done = await _hasSubmittedExpertQuestionnaire();
  if (!context.mounted) return;
  final t = AppLocalizations.of(context);
  if (done) {
    AppToast.show(
      context,
      t.translate("expert_questionnaire_already_done"),
      type: AppToastType.info,
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ExpertQuestionnairePage()),
  );
}

Future<bool> _hasSubmittedExpertQuestionnaire() async {
  final userId = await AccountStorage.getUserId();
  if (userId == null) return false;
  try {
    final profile = await ProfileApi.fetchProfile(userId);
    return profile["filled_expert_questionnaire"] == true;
  } catch (_) {
    return false;
  }
}
