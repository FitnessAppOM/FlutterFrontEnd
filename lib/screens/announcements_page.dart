import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';
import '../../models/news_item.dart';
import '../../services/news/news_tag_actions.dart';
import '../../localization/app_localizations.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({
    super.key,
    required this.items,
  });

  final List<NewsItem> items;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final announcements = items;

    return Scaffold(
      appBar: AppBar(
        title: Text(t("announcements_title")),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionHeader(title: t("latest_news")),
            const SizedBox(height: 12),
            if (announcements.isEmpty)
              CardContainer(
                child: Text(
                  t("no_announcements"),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ...announcements.map((item) {
              final dateLabel = item.createdAt != null
                  ? item.createdAt!.toLocal().toIso8601String().split("T").first
                  : "";
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => NewsTagActions.handleTagTap(context, item.tag, item: item),
                  child: CardContainer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.tag,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (dateLabel.isNotEmpty)
                                Text(
                                  dateLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
