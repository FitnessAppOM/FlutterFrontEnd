import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SavedAccountTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  const SavedAccountTile({
    super.key,
    required this.title,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFCCCCCC),
                ),
                child: const Icon(Icons.person, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                onPressed: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
