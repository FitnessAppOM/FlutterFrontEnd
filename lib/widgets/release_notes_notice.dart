import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      builder: (_) => ReleaseNotesDialog(version: currentVersion),
    );

    await prefs.setString(_prefsKey, currentVersion);
  }
}

class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({super.key, required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E93B),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    'What’s New',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1D17),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Version $version',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1C1D17),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Community UI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1D17),
              ),
            ),
            const SizedBox(height: 8),
            const _ReleaseNoteItem(
              text:
                  'Updated the community experience with refreshed badge and popup UI.',
            ),
            const _ReleaseNoteItem(
              text:
                  'Earned badges now stand out more clearly in the badges screen.',
            ),
            const _ReleaseNoteItem(
              text: 'General fixes and polish across the app.',
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 132,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFFE4E93B),
                    foregroundColor: const Color(0xFF1C1D17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'GOT IT',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseNoteItem extends StatelessWidget {
  const _ReleaseNoteItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF1C1D17)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: Color(0xFF1C1D17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
