import 'dart:convert';
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
import '../welcome.dart';

class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<int?> _checkUserExistsBackend(String email) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/auth/check-user");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      final id = data["user_id"];
      return id is int ? id : int.tryParse(id.toString());
    } catch (_) {
      return null;
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

    final questionnaireDone = qDone || qExpertDone;
    if (email != null &&
        email.isNotEmpty &&
        verified == true &&
        questionnaireDone) {
      final userId = await _checkUserExistsBackend(email);
      if (userId != null) {
        await _navigatePostAuth(userId: userId, isExpert: isExpert);
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
