import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../core/account_storage.dart';
import '../../screens/welcome.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.greyDark,
          child: Icon(Icons.person, size: 48, color: Colors.white),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate("profile_user_name"),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.translate("profile_occupation"),
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white, size: 26),
          onPressed: () {
            // TODO: navigate to Settings
          },
        ),

        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent, size: 26),
          onPressed: () async {
            await AccountStorage.clearSessionOnly();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => WelcomePage(fromLogout: true),
              ),
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}