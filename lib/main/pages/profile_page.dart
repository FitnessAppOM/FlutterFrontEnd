import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_info_section.dart';
import '../../widgets/profile/profile_goals_section.dart';
import '../../widgets/profile/profile_actions_section.dart';
import '../../localization/app_localizations.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // Translator

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text(
          t.translate("profile_title"),   // ← Arabic ready
        ),
        backgroundColor: AppColors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ProfileHeader(),
            SizedBox(height: 24),
            ProfileInfoSection(),
            SizedBox(height: 24),
            ProfileGoalsSection(),
            SizedBox(height: 24),
            ProfileActionsSection(),
          ],
        ),
      ),
    );
  }
}