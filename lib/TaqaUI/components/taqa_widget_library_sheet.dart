import 'dart:math';

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
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
    final width = min(MediaQuery.of(context).size.width * 0.84, TaqaUiScale.w(360));
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: double.infinity,
          padding: EdgeInsets.fromLTRB(
            TaqaUiScale.w(16),
            TaqaUiScale.h(16) + topInset,
            TaqaUiScale.w(16),
            TaqaUiScale.h(20) + bottomInset,
          ),
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: BorderRadius.only(
              topLeft: TaqaUiScale.radius(26).topLeft,
              bottomLeft: TaqaUiScale.radius(26).bottomLeft,
            ),
            boxShadow: const [
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
                  Text(
                    "Widgets",
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      letterSpacing: 0,
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
              Text(
                "Available to add",
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(12),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF636363),
                ),
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              if (options.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      "All widgets are already on your dashboard.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF636363),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) => SizedBox(height: TaqaUiScale.h(10)),
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
      borderRadius: TaqaUiScale.radius(16),
      child: Container(
        padding: TaqaUiScale.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: TaqaUiScale.radius(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.09),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: TaqaUiScale.w(42),
              height: TaqaUiScale.h(42),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: TaqaUiScale.radius(12),
              ),
              child: Icon(option.icon, color: TaqaUiColors.charcoal),
            ),
            SizedBox(width: TaqaUiScale.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(14),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(4)),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(12),
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF636363),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: TaqaUiScale.w(6)),
            Icon(
              Icons.add_circle_outline,
              color: TaqaUiColors.charcoal,
              size: TaqaUiScale.w(18),
            ),
          ],
        ),
      ),
    );
  }
}
