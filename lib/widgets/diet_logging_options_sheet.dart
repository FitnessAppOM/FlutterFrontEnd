import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

class DietLoggingOptionsSheet extends StatelessWidget {
  const DietLoggingOptionsSheet({
    super.key,
    required this.mealTitle,
    required this.onSearch,
    required this.onManualEntry,
    required this.onPhotoEntry,
  });

  final String mealTitle;
  final VoidCallback onSearch;
  final VoidCallback onManualEntry;
  final VoidCallback onPhotoEntry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 44,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.translate("diet_add_item_title"),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                mealTitle,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.search,
              title: t.translate("diet_option_search"),
              subtitle: t.translate("diet_option_search_desc"),
              onTap: () {
                Navigator.of(context).pop();
                // Delay so first sheet is fully disposed before opening second (avoids duplicate GlobalKeys / attached errors)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onSearch();
                });
              },
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.edit,
              title: t.translate("diet_option_manual"),
              subtitle: t.translate("diet_option_manual_desc"),
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onManualEntry();
                });
              },
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.camera_alt,
              title: t.translate("diet_option_photo"),
              subtitle: t.translate("diet_option_photo_desc"),
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onPhotoEntry();
                });
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFD4AF37)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
