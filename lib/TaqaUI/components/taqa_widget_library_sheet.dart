import 'dart:math';

import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_pressable.dart';

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
    final colors = context.taqaColors;
    final t = AppLocalizations.of(context).translate;
    final width = min(
      MediaQuery.of(context).size.width * 0.84,
      TaqaUiScale.w(360),
    );
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
            color: colors.background,
            borderRadius: BorderRadius.only(
              topLeft: TaqaUiScale.radius(26).topLeft,
              bottomLeft: TaqaUiScale.radius(26).bottomLeft,
            ),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.scrim.withValues(alpha: 0.28),
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
                    t("widget_library_title"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      letterSpacing: 0,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: onClose,
                  ),
                ],
              ),
              Text(
                t("widget_library_available"),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(12),
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              if (options.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      t("widget_library_all_added"),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: TaqaUiScale.h(10)),
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

  const _WidgetLibraryTile({required this.option, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return TaqaPressable(
      onTap: onTap,
      child: Container(
        padding: TaqaUiScale.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TaqaUiScale.radius(16),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: TaqaUiScale.w(42),
              height: TaqaUiScale.h(42),
              decoration: BoxDecoration(
                color: option.accentColor.withValues(alpha: 0.16),
                borderRadius: TaqaUiScale.radius(12),
              ),
              child: Icon(option.icon, color: option.accentColor),
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
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(4)),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(12),
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: TaqaUiScale.w(6)),
            Icon(
              Icons.add_circle_outline,
              color: colors.textPrimary,
              size: TaqaUiScale.w(18),
            ),
          ],
        ),
      ),
    );
  }
}
