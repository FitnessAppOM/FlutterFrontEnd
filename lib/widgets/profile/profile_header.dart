import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/welcome.dart';
import '../../screens/settings_page.dart';
import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    this.name,
    this.occupation,
    this.avatarUrl,
  });

  final String? name;
  final String? occupation;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.greyDark,
          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? NetworkImage(_fullUrl(avatarUrl!)) as ImageProvider
              : null,
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? const Icon(Icons.person, size: 48, color: Colors.white)
              : null,
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name ?? t.translate("profile_user_name"),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (occupation != null && occupation!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  occupation!,
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),

        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white, size: 26),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
        ),

        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent, size: 26),
          onPressed: () async {
            await AccountStorage.clearSessionOnly();
            if (!context.mounted) return;
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

  String _fullUrl(String path) {
    if (path.startsWith("http")) return path;
    return "${ApiConfig.baseUrl}$path";
  }
}
