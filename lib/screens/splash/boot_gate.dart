import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../auth/expert_questionnaire.dart';
import '../../auth/questionnaire.dart';
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../../core/locale_controller.dart';
import '../../main/main_layout.dart';
import '../../services/auth/profile_service.dart';
import '../../services/core/navigation_service.dart';
import '../../services/core/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../localization/app_localizations.dart';
import '../welcome.dart';

class _CheckUserResult {
  final int? userId;
  final bool offline;
  const _CheckUserResult({this.userId, this.offline = false});
}

class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  static const Duration _checkTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<_CheckUserResult> _checkUserExistsBackend(String email) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/auth/check-user");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email}),
          )
          .timeout(_checkTimeout);
      if (res.statusCode != 200) return const _CheckUserResult();
      final data = jsonDecode(res.body);
      if (data is! Map) return const _CheckUserResult();
      final id = data["user_id"];
      final userId = id is int ? id : int.tryParse(id.toString());
      return _CheckUserResult(userId: userId);
    } on SocketException {
      return const _CheckUserResult(offline: true);
    } on TimeoutException {
      return const _CheckUserResult(offline: true);
    } on http.ClientException {
      return const _CheckUserResult(offline: true);
    } catch (_) {
      return const _CheckUserResult();
    }
  }

  bool _hasQuestionnaireData(Map<String, dynamic> profile) {
    const keys = [
      "age",
      "fitness_goal",
      "training_days",
      "diet_type",
      "height_cm",
      "weight_kg",
      "sex",
    ];
    return keys.any((k) {
      final v = profile[k];
      if (v == null) return false;
      final s = v.toString().trim();
      return s.isNotEmpty && s != "null";
    });
  }

  Future<void> _navigatePostAuth({
    required int userId,
    required bool isExpert,
  }) async {
    final lang = localeController.locale.languageCode;
    final profile = await ProfileApi.fetchProfile(userId, lang: lang);
    final serverDone = profile["filled_user_questionnaire"] == true;
    final hasData = serverDone || _hasQuestionnaireData(profile);
    await AccountStorage.setQuestionnaireDone(serverDone);
    await AccountStorage.setExpertQuestionnaireDone(serverDone);
    if (!mounted) return;
    if (hasData) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isExpert
              ? const ExpertQuestionnairePage()
              : const QuestionnairePage(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _navigateOfflineMain() async {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (route) => false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        final ctx = NavigationService.navigatorKey.currentContext;
        if (ctx == null) return;
        final t = AppLocalizations.of(ctx);
        AppToast.show(
          ctx,
          t.translate("offline_mode") ?? "Offline Mode",
          type: AppToastType.info,
        );
      });
    });
  }

  Future<void> _boot() async {
    // Skip auto-redirect when app was launched from a notification deep link.
    if (NavigationService.launchedFromNotificationPayload) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WelcomePage(onChangeLanguage: localeController.setLocale),
        ),
      );
      return;
    }

    final email = await AccountStorage.getEmail();
    final verified = await AccountStorage.isVerified();
    final isExpert = await AccountStorage.isExpert();
    final qDone = await AccountStorage.isQuestionnaireDone();
    final qExpertDone = await AccountStorage.isExpertQuestionnaireDone();
    final storedUserId = await AccountStorage.getUserId();
    final token = await AccountStorage.getAccessToken();
    final hasSession = storedUserId != null &&
        storedUserId > 0 &&
        token != null &&
        token.trim().isNotEmpty;

    final questionnaireDone = qDone || qExpertDone;
    if (email != null &&
        email.isNotEmpty &&
        verified == true &&
        questionnaireDone &&
        hasSession) {
      final result = await _checkUserExistsBackend(email);
      if (result.offline) {
        await _navigateOfflineMain();
        return;
      }
      if (result.userId != null) {
        await _navigatePostAuth(userId: result.userId!, isExpert: isExpert);
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomePage(onChangeLanguage: localeController.setLocale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}
