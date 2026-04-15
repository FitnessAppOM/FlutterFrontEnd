import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseNotesNotice {
  static const String _prefsKey = 'release_notes_shown_version';

  static Future<void> showIfNeeded(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version.trim();
    if (currentVersion.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final shownVersion = prefs.getString(_prefsKey);
    if (shownVersion == currentVersion) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ReleaseNotesDialog(),
    );

    await prefs.setString(_prefsKey, currentVersion);
  }
}

class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'What’s new',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReleaseNoteHighlight(text: 'v1.0.24'),
          SizedBox(height: 10),
          _ReleaseNoteItem(text: 'TAQA score v2'),
          _ReleaseNoteItem(text: 'Form check video(coach page)'),
        ],
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

class _ReleaseNoteHighlight extends StatelessWidget {
  final String text;

  const _ReleaseNoteHighlight({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFFD4AF37),
      ),
    );
  }
}

class _ReleaseNoteItem extends StatelessWidget {
  final String text;

  const _ReleaseNoteItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '• $text',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}
