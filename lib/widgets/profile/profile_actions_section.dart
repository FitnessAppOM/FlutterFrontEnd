import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class ProfileActionsSection extends StatelessWidget {
  const ProfileActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // Translator

    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () {},
          child: Text(t.translate("edit_profile")),
        ),
        const SizedBox(height: 12),
       
      ],
    );
  }
}
