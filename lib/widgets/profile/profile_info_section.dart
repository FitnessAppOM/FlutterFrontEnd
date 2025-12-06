import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import 'section_title.dart';

class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({
    super.key,
    required this.age,
    required this.sex,
    required this.height,
    required this.occupation,
    required this.weight,
  });

  final String age;
  final String sex;
  final String height;
  final String occupation;
  final String weight;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(text: t.translate("profile_info_title")),
        const SizedBox(height: 12),

        _infoTile(t.translate("profile_age"), age),
        _infoTile(t.translate("profile_sex"), sex),
        _infoTile(t.translate("profile_height"), height),
        _infoTile(t.translate("profile_weight"), weight),
        _infoTile(t.translate("profile_occupation"), occupation),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
