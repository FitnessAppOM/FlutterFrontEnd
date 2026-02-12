import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WidgetLibraryOption {
  final String keyName;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const WidgetLibraryOption({
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class WidgetLibrarySheet extends StatelessWidget {
  final List<WidgetLibraryOption> options;
  final VoidCallback? onClose;
  final ValueChanged<WidgetLibraryOption>? onSelect;

  const WidgetLibrarySheet({
    super.key,
    required this.options,
    this.onClose,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final width = min(MediaQuery.of(context).size.width * 0.82, 360.0);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: double.infinity,
          padding: EdgeInsets.fromLTRB(16, 16 + topInset, 16, 20 + bottomInset),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D1F27), Color(0xFF13151C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              bottomLeft: Radius.circular(26),
            ),
            border: Border.all(color: AppColors.dividerDark),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Widgets",
                    style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
              Text(
                "Available to add",
                style: AppTextStyles.small.copyWith(color: AppColors.textDim),
              ),
              const SizedBox(height: 12),
              if (options.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      "All widgets are already on your dashboard.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.small.copyWith(color: AppColors.textDim),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return _WidgetLibraryTile(
                        option: option,
                        onTap: () => onSelect?.call(option),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetLibraryTile extends StatelessWidget {
  final WidgetLibraryOption option;
  final VoidCallback? onTap;

  const _WidgetLibraryTile({
    required this.option,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: option.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: option.accentColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: option.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon, color: option.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: AppTextStyles.small.copyWith(color: AppColors.textDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
