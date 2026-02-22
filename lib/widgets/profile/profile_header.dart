import 'dart:io';

import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/welcome.dart';
import '../../screens/settings_page.dart';
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../../services/core/notification_service.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    this.name,
    this.occupation,
    this.avatarUrl,
    this.avatarPath,
  });

  final String? name;
  final String? occupation;
  final String? avatarUrl;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ImageProvider? avatarImage = _resolveAvatarImage();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.greyDark,
          backgroundImage: avatarImage,
          child: avatarImage == null
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
            // Clear first so a later login is never overwritten by a delayed clear.
            await AccountStorage.clearSessionOnly();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => WelcomePage(fromLogout: true),
              ),
              (route) => false,
            );
            // Refresh notifications after leaving; don't await so we don't race with new login.
            NotificationService.refreshDailyJournalRemindersForCurrentUser();
          },
        ),
      ],
    );
  }

  String _fullUrl(String path) {
    if (path.startsWith("http")) return path;
    return "${ApiConfig.baseUrl}$path";
  }

  ImageProvider? _resolveAvatarImage() {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return NetworkImage(_fullUrl(avatarUrl!));
    }
    return null;
  }
}
