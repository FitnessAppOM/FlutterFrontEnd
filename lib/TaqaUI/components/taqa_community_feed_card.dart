import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';
import 'taqa_mini_tag.dart';

class TaqaCommunityFeedCard extends StatelessWidget {
  const TaqaCommunityFeedCard({
    super.key,
    required this.actorLabel,
    this.actorAvatarUrl,
    required this.chips,
    required this.title,
    this.subtitle,
    this.payloadEntries = const [],
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    this.canComment = true,
    this.onLikeTap,
    this.onCommentTap,
    this.trailing,
  });

  final String actorLabel;
  final String? actorAvatarUrl;
  final List<String> chips;
  final String title;
  final String? subtitle;
  final List<MapEntry<String, String>> payloadEntries;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final bool canComment;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final padding = TaqaUiScale.w(14);
    final gap = TaqaUiScale.w(6);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaqaFeedAvatar(url: actorAvatarUrl, label: actorLabel),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actorLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.dailyOutlookTitle,
                    ),
                    if (chips.isNotEmpty) ...[
                      SizedBox(height: TaqaUiScale.h(6)),
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: chips
                            .map((label) => TaqaMiniTag(label: label))
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          Text(
            title,
            style: TaqaUiStyles.dailyOutlookTitle,
          ),
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(8)),
            Text(
              subtitle!,
              style: TaqaUiStyles.dailyOutlookDescription,
            ),
          ],
          if (payloadEntries.isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(12)),
            Wrap(
              spacing: TaqaUiScale.w(8),
              runSpacing: TaqaUiScale.h(8),
              children: payloadEntries
                  .map((entry) => _TaqaFeedPayloadChip(label: entry.key, value: entry.value))
                  .toList(growable: false),
            ),
          ],
          SizedBox(height: TaqaUiScale.h(16)),
          Row(
            children: [
              _TaqaFeedActionButton(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: '$likeCount',
                accent: liked,
                onTap: onLikeTap,
              ),
              SizedBox(width: TaqaUiScale.w(10)),
              _TaqaFeedActionButton(
                icon: Icons.chat_bubble_outline,
                label: '$commentCount',
                enabled: canComment,
                onTap: canComment ? onCommentTap : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaqaFeedAvatar extends StatelessWidget {
  const _TaqaFeedAvatar({required this.url, required this.label});

  final String? url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final size = TaqaUiScale.w(40);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TaqaUiColors.lightGray,
        shape: BoxShape.circle,
        image: url != null
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '?',
              style: TaqaUiStyles.dailyOutlookButton,
            )
          : null,
    );
  }
}


class _TaqaFeedPayloadChip extends StatelessWidget {
  const _TaqaFeedPayloadChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: TaqaUiColors.lightGray,
        borderRadius: TaqaUiScale.radius(10),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TaqaUiStyles.dailyOutlookTag,
            ),
            TextSpan(
              text: value,
              style: TaqaUiStyles.dailyOutlookTag.copyWith(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaqaFeedActionButton extends StatelessWidget {
  const _TaqaFeedActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? TaqaUiColors.charcoal
        : TaqaUiColors.charcoal.withValues(alpha: 0.32);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: TaqaUiScale.radius(999),
        child: Container(
          padding: TaqaUiScale.insetsLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: accent ? TaqaUiColors.lime : TaqaUiColors.lightGray,
            borderRadius: TaqaUiScale.radius(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: TaqaUiScale.w(16), color: color),
              SizedBox(width: TaqaUiScale.w(6)),
              Text(
                label,
                style: TaqaUiStyles.dailyOutlookButton.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
