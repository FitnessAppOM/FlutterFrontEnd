import 'dart:math';

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

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
    final width = min(MediaQuery.of(context).size.width * 0.84, 360.0);
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
          decoration: const BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(26),
              bottomLeft: Radius.circular(26),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 30,
                offset: Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Widgets",
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: onClose,
                  ),
                ],
              ),
              const Text(
                "Available to add",
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF636363),
                ),
              ),
              const SizedBox(height: 12),
              if (options.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "All widgets are already on your dashboard.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF636363),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
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
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.09),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon, color: TaqaUiColors.charcoal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF636363),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.add_circle_outline,
              color: TaqaUiColors.charcoal,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
