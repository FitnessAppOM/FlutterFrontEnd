import 'package:flutter/material.dart';

import '../styles/taqa_ui_styles.dart';
import 'taqa_outline_tag_button.dart';

class TaqaCommunitySectionHeader extends StatelessWidget {
  const TaqaCommunitySectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TaqaUiStyles.userName,
          ),
        ),
        if (actionLabel != null)
          TaqaOutlineTagButton(
            label: actionLabel!,
            width: TaqaUiStyles.communitySectionTagWidth,
            onTap: onActionTap,
          ),
      ],
    );
  }
}
