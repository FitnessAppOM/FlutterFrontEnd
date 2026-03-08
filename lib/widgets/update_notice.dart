import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateNotice {
  static const String currentVersion = '1.0.4';
  static const String _prefsKey = 'update_notice_shown_version';

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final shownVersion = prefs.getString(_prefsKey);
    if (shownVersion == currentVersion) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const UpdateNoticeDialog(),
    );

    await prefs.setString(_prefsKey, currentVersion);
  }
}

class UpdateNoticeDialog extends StatelessWidget {
  const UpdateNoticeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Please update',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'A newer version is available. Please update TaqaFitness for the best experience.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
