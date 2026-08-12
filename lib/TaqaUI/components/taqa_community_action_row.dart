import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../Typography/taqa_ui_typography.dart';
import '../../localization/app_localizations.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityActionRow extends StatelessWidget {
  const TaqaCommunityActionRow({
    super.key,
    required this.onDiscoverTap,
    required this.onJoinByCodeTap,
    required this.onCreateGroupTap,
  });

  final VoidCallback onDiscoverTap;
  final VoidCallback onJoinByCodeTap;
  final VoidCallback onCreateGroupTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.communityActionRowWidth,
        );
        final layoutScale = math.min(
          1.0,
          rowWidth / TaqaUiStyles.communityActionRowWidth,
        );
        final buttonWidth =
            TaqaUiStyles.communityActionButtonWidth * layoutScale;
        final buttonHeight = TaqaUiStyles.actionButtonHeight * layoutScale;
        final gap = TaqaUiScale.w(15) * layoutScale;

        return SizedBox(
          width: rowWidth,
          height: buttonHeight,
          child: Row(
            children: [
              _TaqaCommunityActionButton(
                label: t.translate('community_discover'),
                width: buttonWidth,
                height: buttonHeight,
                onTap: onDiscoverTap,
              ),
              SizedBox(width: gap),
              _TaqaCommunityActionButton(
                label: t.translate('community_join_by_code'),
                width: buttonWidth,
                height: buttonHeight,
                onTap: onJoinByCodeTap,
              ),
              SizedBox(width: gap),
              _TaqaCommunityActionButton(
                label: t.translate('community_create_group'),
                width: buttonWidth,
                height: buttonHeight,
                onTap: onCreateGroupTap,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaqaCommunityActionButton extends StatelessWidget {
  const _TaqaCommunityActionButton({
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.actionButtonRadius,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TaqaUiColors.charcoal,
            borderRadius: TaqaUiStyles.actionButtonRadius,
          ),
          child: Text(
            taqaUppercase(label),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TaqaUiStyles.communityActionButtonLabel,
          ),
        ),
      ),
    );
  }
}
