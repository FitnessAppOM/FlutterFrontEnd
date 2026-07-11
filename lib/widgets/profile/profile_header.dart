import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/base_url.dart';
import '../../localization/app_localizations.dart';
import '../../screens/settings_page.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_adaptive_name_text.dart';

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: TaqaUiScale.w(62),
          width: TaqaUiScale.w(62),
          child: CircleAvatar(
            backgroundColor: TaqaUiColors.unnamedColor1c1d17,
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Icon(
                    Icons.person,
                    size: TaqaUiScale.w(32),
                    color: TaqaUiColors.white,
                  )
                : null,
          ),
        ),
        SizedBox(width: TaqaUiScale.w(15)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaqaAdaptiveNameText(
                welcomeText: name ?? t.translate("profile_user_name"),
                userNameText: name ?? t.translate("profile_user_name"),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(25),
                  fontWeight: FontWeight.w700,
                  height: 25 / 25,
                  letterSpacing: 0,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              if (occupation != null && occupation!.trim().isNotEmpty) ...[
                SizedBox(height: TaqaUiScale.h(4)),
                Text(
                  occupation!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w400,
                    height: 18 / 15,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ],
            ],
          ),
        ),
        InkWell(
          borderRadius: TaqaUiScale.radius(5),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          child: Container(
            height: TaqaUiScale.h(20),
            padding: TaqaUiScale.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: TaqaUiColors.unnamedColor1c1d17,
                width: 0.5,
              ),
              borderRadius: TaqaUiScale.radius(5),
            ),
            child: Text(
              t.translate("settings").toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w600,
                height: 12 / 10,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider? _resolveAvatarImage() {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    final normalizedUrl = _normalizeAvatarUrl(avatarUrl);
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      return CachedNetworkImageProvider(normalizedUrl);
    }
    return null;
  }

  String? _normalizeAvatarUrl(String? rawValue) {
    final raw = rawValue?.trim() ?? '';
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return raw;
    }
    final base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) return null;
    try {
      final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
      return baseUri.resolve(raw).toString();
    } catch (_) {
      return null;
    }
  }
}
