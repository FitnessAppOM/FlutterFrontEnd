import 'dart:async';

import 'package:flutter/material.dart';
import '../../main/main_layout.dart';
import '../../core/account_storage.dart';
import '../coach/coach_support_chat_service.dart';
import '../../screens/coach_page.dart';
import '../../screens/expert_client_chat_page.dart';
import '../../screens/expert_client_habits_page.dart';
import '../../screens/expert_client_diet_review_page.dart';
import '../../screens/daily_journal.dart';

enum _NotificationAccessState { allowed, subscriptionRequired, unavailable }

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool launchedFromNotificationPayload = false;
  static bool isOnJournalPage = false;
  static bool _journalNotificationPending = false;
  static bool _dietNotificationPending = false;
  static bool _expertAiUpdatesNotificationPending = false;
  static bool _trainingPlanChangeNotificationPending = false;
  static bool _notificationNavigationReady = false;
  static Completer<void> _startupReady = Completer<void>();
  static String? _pendingNotificationType;
  static int? _pendingNotificationSenderUserId;
  static String? _pendingNotificationSenderRole;
  static int? _pendingNotificationClientUserId;
  static int? _pendingNotificationCoachUserId;
  static int? _pendingNotificationGroupId;

  static bool get journalNotificationPending => _journalNotificationPending;
  static bool get dietNotificationPending => _dietNotificationPending;
  static bool get expertAiUpdatesNotificationPending =>
      _expertAiUpdatesNotificationPending;
  static bool get notificationNavigationReady => _notificationNavigationReady;

  static Future<void> waitUntilStartupReady({Duration? timeout}) async {
    if (timeout == null) {
      await _startupReady.future;
      return;
    }
    try {
      await _startupReady.future.timeout(timeout);
    } on TimeoutException {
      // Optional bounded waits may continue with best-effort background work.
    }
  }

  static void setNotificationNavigationReady(bool value) {
    if (!value && _notificationNavigationReady) {
      _startupReady = Completer<void>();
    }
    _notificationNavigationReady = value;
    if (value && !_startupReady.isCompleted) {
      _startupReady.complete();
    }
  }

  static void markJournalNotificationPending() {
    _journalNotificationPending = true;
    launchedFromNotificationPayload = true;
  }

  static void markDietNotificationPending() {
    _dietNotificationPending = true;
  }

  static void markExpertAiUpdatesNotificationPending() {
    _expertAiUpdatesNotificationPending = true;
    launchedFromNotificationPayload = true;
  }

  static void markTrainingPlanChangeNotificationPending() {
    _trainingPlanChangeNotificationPending = true;
    launchedFromNotificationPayload = true;
  }

  static bool consumeTrainingPlanChangeNotification() {
    final pending = _trainingPlanChangeNotificationPending;
    _trainingPlanChangeNotificationPending = false;
    launchedFromNotificationPayload = false;
    return pending;
  }

  static bool consumeJournalNotification() {
    final pending = _journalNotificationPending;
    _journalNotificationPending = false;
    launchedFromNotificationPayload = false;
    return pending;
  }

  static bool consumeExpertAiUpdatesNotification() {
    final pending = _expertAiUpdatesNotificationPending;
    _expertAiUpdatesNotificationPending = false;
    launchedFromNotificationPayload = false;
    return pending;
  }

  static void queuePendingNotificationNavigation({
    required String type,
    int? senderUserId,
    String? senderRole,
    int? clientUserId,
    int? coachUserId,
    int? groupId,
  }) {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.isEmpty) return;
    _pendingNotificationType = normalizedType;
    _pendingNotificationSenderUserId = senderUserId;
    _pendingNotificationSenderRole = senderRole;
    _pendingNotificationClientUserId = clientUserId;
    _pendingNotificationCoachUserId = coachUserId;
    _pendingNotificationGroupId = groupId;
    launchedFromNotificationPayload = true;
  }

  static Future<void> handleNotificationTap({
    required String type,
    int? senderUserId,
    String? senderRole,
    int? clientUserId,
    int? coachUserId,
    int? groupId,
  }) async {
    queuePendingNotificationNavigation(
      type: type,
      senderUserId: senderUserId,
      senderRole: senderRole,
      clientUserId: clientUserId,
      coachUserId: coachUserId,
      groupId: groupId,
    );
    if (!_notificationNavigationReady) return;
    await flushPendingNotificationNavigation();
  }

  static Future<bool> flushPendingNotificationNavigation() async {
    if (!_notificationNavigationReady) return false;
    final pendingType = (_pendingNotificationType ?? '').trim();
    if (pendingType.isEmpty) return false;

    final userId = await AccountStorage.getUserId();
    final token = await AccountStorage.getAccessToken();
    final hasSession =
        userId != null &&
        userId > 0 &&
        token != null &&
        token.trim().isNotEmpty;
    if (!hasSession) return false;

    final nav = navigatorKey.currentState;
    if (nav == null) return false;

    final access = await _cachedNotificationAccess();
    if (access == _NotificationAccessState.unavailable) {
      // Never consume or open a notification destination unless access was
      // verified. Keeping it queued lets a later retry deliver it safely.
      return false;
    }
    if (access == _NotificationAccessState.subscriptionRequired) {
      setNotificationNavigationReady(false);
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainLayout(initialSubscriptionRequired: true),
        ),
        (_) => false,
      );
      return true;
    }

    final type = pendingType;
    final senderUserId = _pendingNotificationSenderUserId;
    final senderRole = _pendingNotificationSenderRole;
    final clientUserId = _pendingNotificationClientUserId;
    final coachUserId = _pendingNotificationCoachUserId;
    final groupId = _pendingNotificationGroupId;

    _pendingNotificationType = null;
    _pendingNotificationSenderUserId = null;
    _pendingNotificationSenderRole = null;
    _pendingNotificationClientUserId = null;
    _pendingNotificationCoachUserId = null;
    _pendingNotificationGroupId = null;
    launchedFromNotificationPayload = false;

    final effectiveClientId = clientUserId ?? senderUserId;
    if (type == 'daily_journal') {
      await navigateToJournal(fromNotification: true);
      return true;
    }
    if (type == 'diet') {
      await navigateToDiet(fromNotification: true);
      return true;
    }
    if (type == 'expert_ai_updates') {
      await navigateToExpertDashboard(fromNotification: true);
      return true;
    }
    if (type == 'coach_application_decision') {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const MainLayout(initialIndex: MainLayout.coachTabIndex),
        ),
        (_) => false,
      );
      return true;
    }
    if (type == 'coach_chat') {
      await navigateToChatFromNotification(
        senderUserId: senderUserId ?? clientUserId,
        senderRole: senderRole,
      );
      return true;
    }
    if (type == 'habit_reminder') {
      final isExpert = await AccountStorage.isExpert();
      if (isExpert && (effectiveClientId ?? 0) > 0) {
        await navigateToExpertClientHabitsFromNotification(
          clientUserId: effectiveClientId!,
        );
      } else {
        await navigateToCoachFeedback();
      }
      return true;
    }
    if (type == 'coach_habit_added') {
      final isExpert = await AccountStorage.isExpert();
      if (isExpert && (effectiveClientId ?? 0) > 0) {
        await navigateToExpertClientHabitsFromNotification(
          clientUserId: effectiveClientId!,
        );
      } else {
        await navigateToCoachFeedback();
      }
      return true;
    }
    if (type == 'coach_feedback_added') {
      final isExpert = await AccountStorage.isExpert();
      if (isExpert && (effectiveClientId ?? 0) > 0) {
        await navigateToExpertClientDietReviewFromNotification(
          clientUserId: effectiveClientId!,
        );
      } else {
        await navigateToCoachFeedback();
      }
      return true;
    }
    if (type == 'training_plan_change') {
      markTrainingPlanChangeNotificationPending();
      await navigateToTrain(fromNotification: true);
      return true;
    }
    if (type == 'diet_target_change') {
      await navigateToDiet(fromNotification: false);
      return true;
    }
    if (type == 'coach_connection_request_decision') {
      await navigateToCoachFeedback();
      return true;
    }
    if (type == 'community') {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainLayout(
            initialIndex: MainLayout.communityTabIndex,
            initialCommunityGroupId: groupId,
          ),
        ),
        (_) => false,
      );
      return true;
    }
    if ((coachUserId ?? 0) > 0) {
      await navigateToCoachChat(coachUserId: coachUserId);
      return true;
    }
    return false;
  }

  static Future<Widget?> consumeDirectNotificationTarget({
    bool? initialSubscriptionRequired,
  }) async {
    final pendingType = (_pendingNotificationType ?? '').trim();
    if (pendingType.isEmpty) return null;

    final access = initialSubscriptionRequired == true
        ? _NotificationAccessState.subscriptionRequired
        : initialSubscriptionRequired == false
        ? _NotificationAccessState.allowed
        : await _cachedNotificationAccess();
    if (access == _NotificationAccessState.unavailable) return null;
    if (access == _NotificationAccessState.subscriptionRequired) {
      // Do not consume the destination. MainLayout will show the mandatory
      // plan page, then deliver this notification after access is restored.
      return const MainLayout(initialSubscriptionRequired: true);
    }

    final type = pendingType;
    final senderUserId = _pendingNotificationSenderUserId;
    final senderRole = (_pendingNotificationSenderRole ?? '')
        .trim()
        .toLowerCase();
    final clientUserId = _pendingNotificationClientUserId;
    final coachUserId = _pendingNotificationCoachUserId;
    final groupId = _pendingNotificationGroupId;
    final effectiveClientId = clientUserId ?? senderUserId;

    _pendingNotificationType = null;
    _pendingNotificationSenderUserId = null;
    _pendingNotificationSenderRole = null;
    _pendingNotificationClientUserId = null;
    _pendingNotificationCoachUserId = null;
    _pendingNotificationGroupId = null;
    launchedFromNotificationPayload = false;

    if (type == 'daily_journal') {
      return const DailyJournalPage();
    }
    if (type == 'diet') {
      return MainLayout(
        initialIndex: 0,
        initialSubscriptionRequired: initialSubscriptionRequired,
      );
    }
    if (type == 'expert_ai_updates') {
      return MainLayout(
        initialIndex: MainLayout.coachTabIndex,
        autoOpenExpertDashboard: true,
        initialSubscriptionRequired: initialSubscriptionRequired,
      );
    }
    if (type == 'coach_application_decision') {
      return MainLayout(
        initialIndex: MainLayout.coachTabIndex,
        initialSubscriptionRequired: initialSubscriptionRequired,
      );
    }
    if (type == 'training_plan_change') {
      markTrainingPlanChangeNotificationPending();
      return MainLayout(
        initialIndex: 1,
        initialSubscriptionRequired: initialSubscriptionRequired,
      );
    }
    if (type == 'diet_target_change') {
      return MainLayout(
        initialIndex: 0,
        initialSubscriptionRequired: initialSubscriptionRequired,
      );
    }
    if (type == 'coach_connection_request_decision') {
      return const CoachPage(initialTabIndex: 0);
    }
    if (type == 'community') {
      return MainLayout(
        initialIndex: MainLayout.communityTabIndex,
        initialSubscriptionRequired: initialSubscriptionRequired,
        initialCommunityGroupId: groupId,
      );
    }
    if (type == 'habit_reminder' || type == 'coach_habit_added') {
      final isExpert = await AccountStorage.isExpert();
      if (isExpert && (effectiveClientId ?? 0) > 0) {
        return ExpertClientHabitsPage(
          clientId: effectiveClientId!,
          clientName: 'Client',
        );
      }
      return const CoachPage(initialTabIndex: 0);
    }
    if (type == 'coach_feedback_added') {
      final isExpert = await AccountStorage.isExpert();
      if (isExpert && (effectiveClientId ?? 0) > 0) {
        return ExpertClientDietReviewPage(
          clientUserId: effectiveClientId!,
          clientName: 'Client',
        );
      }
      return const CoachPage(initialTabIndex: 0);
    }
    if (type == 'coach_chat') {
      final senderId = senderUserId ?? clientUserId ?? 0;
      if (senderRole == 'coach') {
        return CoachPage(
          initialTabIndex: 1,
          initialCoachUserId: senderId > 0 ? senderId : null,
        );
      }
      final isExpert = await AccountStorage.isExpert();
      final canOpenAsExpert = senderId > 0
          ? await _canOpenExpertThreadForSender(senderId)
          : false;
      if ((senderRole == 'client' && senderId > 0) ||
          (senderId > 0 && (isExpert || canOpenAsExpert))) {
        return ExpertClientChatPage(
          clientUserId: senderId,
          clientName: 'Client',
        );
      }
      return CoachPage(
        initialTabIndex: 1,
        initialCoachUserId: coachUserId ?? (senderId > 0 ? senderId : null),
      );
    }
    if ((coachUserId ?? 0) > 0) {
      return CoachPage(initialTabIndex: 1, initialCoachUserId: coachUserId);
    }
    return null;
  }

  static Future<_NotificationAccessState> _cachedNotificationAccess() async {
    final allowed = await AccountStorage.cachedSubscriptionAccessAllowed();
    if (allowed == true) return _NotificationAccessState.allowed;
    if (allowed == false) return _NotificationAccessState.subscriptionRequired;
    return _NotificationAccessState.unavailable;
  }

  static Future<void> navigateToJournal({bool fromNotification = false}) async {
    if (fromNotification) {
      markJournalNotificationPending();
    }

    if (isOnJournalPage) {
      if (fromNotification) {
        _journalNotificationPending = false;
        launchedFromNotificationPayload = false;
      }
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Use pushNamed to allow back navigation to previous stack.
    nav.pushNamed('/daily-journal');
  }

  static Future<void> navigateToDiet({bool fromNotification = false}) async {
    if (fromNotification) {
      _dietNotificationPending = true;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Reset to main layout and select the Diet tab.
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 0)),
      (_) => false,
    );
  }

  static Future<void> navigateToTrain({bool fromNotification = false}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 1)),
      (_) => false,
    );
  }

  static Future<void> navigateToFeed({bool fromNotification = false}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 3)),
      (_) => false,
    );
  }

  static Future<void> navigateToExpertDashboard({
    bool fromNotification = false,
  }) async {
    if (fromNotification) {
      _expertAiUpdatesNotificationPending = false;
      launchedFromNotificationPayload = false;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => const MainLayout(
          initialIndex: MainLayout.coachTabIndex,
          autoOpenExpertDashboard: true,
        ),
      ),
    );
  }

  static Future<void> navigateToCoachPage({
    int initialTabIndex = 0,
    int? initialCoachUserId,
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => CoachPage(
          initialTabIndex: initialTabIndex,
          initialCoachUserId: initialCoachUserId,
        ),
      ),
    );
  }

  static Future<void> navigateToCoachChat({int? coachUserId}) async {
    await navigateToCoachPage(
      initialTabIndex: 1,
      initialCoachUserId: coachUserId,
    );
  }

  static Future<void> navigateToCoachFeedback() async {
    await navigateToCoachPage(initialTabIndex: 0);
  }

  static Future<void> navigateToExpertClientHabitsFromNotification({
    required int clientUserId,
    String clientName = 'Client',
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => ExpertClientHabitsPage(
          clientId: clientUserId,
          clientName: clientName,
        ),
      ),
    );
  }

  static Future<void> navigateToExpertClientDietReviewFromNotification({
    required int clientUserId,
    String clientName = 'Client',
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => ExpertClientDietReviewPage(
          clientUserId: clientUserId,
          clientName: clientName,
        ),
      ),
    );
  }

  static Future<void> navigateToChatFromNotification({
    int? senderUserId,
    String? senderRole,
  }) async {
    final normalizedSenderRole = (senderRole ?? '').trim().toLowerCase();
    final isExpert = await AccountStorage.isExpert();
    final senderId = senderUserId ?? 0;
    final canOpenAsExpert = senderId > 0
        ? await _canOpenExpertThreadForSender(senderId)
        : false;
    if (normalizedSenderRole == 'client' && senderId > 0) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ExpertClientChatPage(
            clientUserId: senderId,
            clientName: 'Client',
          ),
        ),
      );
      return;
    }
    if (normalizedSenderRole == 'coach') {
      await navigateToCoachChat(coachUserId: senderId > 0 ? senderId : null);
      return;
    }
    if (senderId > 0 && (isExpert || canOpenAsExpert)) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ExpertClientChatPage(
            clientUserId: senderId,
            clientName: 'Client',
          ),
        ),
      );
      return;
    }
    await navigateToCoachChat(coachUserId: senderUserId);
  }

  static Future<bool> _canOpenExpertThreadForSender(int senderId) async {
    try {
      await CoachSupportChatService.fetchCoachClientThread(
        clientUserId: senderId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool consumeDietNotification() {
    final pending = _dietNotificationPending;
    _dietNotificationPending = false;
    return pending;
  }
}
