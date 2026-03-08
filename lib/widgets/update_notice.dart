import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/core/app_version_service.dart';

class UpdateNotice {
  static Future<void> showIfNeeded(BuildContext context) async {
    final info = await AppVersionService.fetchRemoteVersion();
    if (info == null) return;

    final current = (await PackageInfo.fromPlatform()).version;
    final minVersion = info.minVersion?.trim();
    final latestVersion = info.latestVersion?.trim();

    if ((minVersion == null || minVersion.isEmpty) &&
        (latestVersion == null || latestVersion.isEmpty)) {
      return;
    }

    bool isOlderThan(String target) => _compareVersions(current, target) < 0;

    final forceUpdate = info.forceUpdate ||
        (minVersion != null && minVersion.isNotEmpty && isOlderThan(minVersion));

    if (forceUpdate) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateNoticeDialog(
          message: info.message ??
              'A newer version is required. Please update TaqaFitness to continue.',
          force: true,
        ),
      );
      return;
    }

    if (latestVersion != null &&
        latestVersion.isNotEmpty &&
        isOlderThan(latestVersion)) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'update_notice_shown_latest';
      final shown = prefs.getString(key);
      if (shown == latestVersion) return;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdateNoticeDialog(
          message: info.message ??
              'A newer version is available. Please update TaqaFitness for the best experience.',
        ),
      );
      await prefs.setString(key, latestVersion);
    }
  }

  static int _compareVersions(String a, String b) {
    List<int> parse(String v) {
      final main = v.split('+').first;
      return main
          .split('.')
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .toList();
    }

    final va = parse(a);
    final vb = parse(b);
    final maxLen = va.length > vb.length ? va.length : vb.length;
    for (int i = 0; i < maxLen; i++) {
      final ai = i < va.length ? va[i] : 0;
      final bi = i < vb.length ? vb[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }
}

class UpdateNoticeDialog extends StatelessWidget {
  const UpdateNoticeDialog({
    super.key,
    required this.message,
    this.force = false,
  });

  final String message;
  final bool force;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Please update',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(force ? 'Update required' : 'OK'),
        ),
      ],
    );
  }
}
