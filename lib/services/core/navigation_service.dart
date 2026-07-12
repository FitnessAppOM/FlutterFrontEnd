import 'package:flutter/material.dart';
import '../../main/main_layout.dart';
import '../../core/account_storage.dart';
import '../../screens/expert_dashboard_page.dart';
import '../coach/coach_support_chat_service.dart';
import '../../screens/coach_page.dart';
import '../../screens/expert_client_chat_page.dart';
import '../../screens/expert_client_habits_page.dart';
import '../../screens/expert_client_diet_review_page.dart';

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
  static String? _pendingNotificationType;
  static int? _pendingNotificationSenderUserId;
  static String? _pendingNotificationSenderRole;
  static int? _pendingNotificationClientUserId;
  static int? _pendingNotificationCoachUserId;

  static bool get journalNotificationPending => _journalNotificationPending;
  static bool get dietNotificationPending => _dietNotificationPending;
  static bool get expertAiUpdatesNotificationPending =>
      _expertAiUpdatesNotificationPending;
  static bool get notificationNavigationReady => _notificationNavigationReady;

  static void setNotificationNavigationReady(bool value) {
    _notificationNavigationReady = value;
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
  }) {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.isEmpty) return;
    _pendingNotificationType = normalizedType;
    _pendingNotificationSenderUserId = senderUserId;
    _pendingNotificationSenderRole = senderRole;
    _pendingNotificationClientUserId = clientUserId;
    _pendingNotificationCoachUserId = coachUserId;
    launchedFromNotificationPayload = true;
  }

  static Future<void> handleNotificationTap({
    required String type,
    int? senderUserId,
    String? senderRole,
    int? clientUserId,
    int? coachUserId,
  }) async {
    queuePendingNotificationNavigation(
      type: type,
      senderUserId: senderUserId,
      senderRole: senderRole,
      clientUserId: clientUserId,
      coachUserId: coachUserId,
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

    final type = pendingType;
    final senderUserId = _pendingNotificationSenderUserId;
    final senderRole = _pendingNotificationSenderRole;
    final clientUserId = _pendingNotificationClientUserId;
    final coachUserId = _pendingNotificationCoachUserId;

    _pendingNotificationType = null;
    _pendingNotificationSenderUserId = null;
    _pendingNotificationSenderRole = null;
    _pendingNotificationClientUserId = null;
    _pendingNotificationCoachUserId = null;
    launchedFromNotificationPayload = false;

    final effectiveClientId = clientUserId ?? senderUserId;
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
    if ((coachUserId ?? 0) > 0) {
      await navigateToCoachChat(coachUserId: coachUserId);
      return true;
    }
    return false;
  }

  static Future<Widget?> consumeDirectNotificationTarget() async {
    final pendingType = (_pendingNotificationType ?? '').trim();
    if (pendingType.isEmpty) return null;

    final type = pendingType;
    final senderUserId = _pendingNotificationSenderUserId;
    final senderRole = (_pendingNotificationSenderRole ?? '')
        .trim()
        .toLowerCase();
    final clientUserId = _pendingNotificationClientUserId;
    final coachUserId = _pendingNotificationCoachUserId;
    final effectiveClientId = clientUserId ?? senderUserId;

    _pendingNotificationType = null;
    _pendingNotificationSenderUserId = null;
    _pendingNotificationSenderRole = null;
    _pendingNotificationClientUserId = null;
    _pendingNotificationCoachUserId = null;
    launchedFromNotificationPayload = false;

    if (type == 'training_plan_change') {
      markTrainingPlanChangeNotificationPending();
      return const MainLayout(initialIndex: 1);
    }
    if (type == 'diet_target_change') {
      return const MainLayout(initialIndex: 0);
    }
    if (type == 'coach_connection_request_decision') {
      return const CoachPage(initialTabIndex: 0);
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

    nav.push(MaterialPageRoute(builder: (_) => const ExpertDashboardPage()));
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
