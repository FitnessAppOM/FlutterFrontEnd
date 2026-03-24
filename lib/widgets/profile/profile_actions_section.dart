import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class ProfileActionsSection extends StatelessWidget {
  const ProfileActionsSection({
    super.key,
    required this.onEditProfile,
    this.editEnabled = true,
  });

  final VoidCallback onEditProfile;
  final bool editEnabled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // Translator

    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: editEnabled ? Colors.white : Colors.white24,
            foregroundColor: editEnabled ? Colors.black : Colors.white54,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: editEnabled ? onEditProfile : null,
          child: Text(t.translate("edit_profile")),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
