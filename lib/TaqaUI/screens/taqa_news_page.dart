import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../components/taqa_back_button.dart';
import '../components/taqa_page_header.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/news_item.dart';
import '../../../services/news/news_tag_actions.dart';

class TaqaNewsPage extends StatelessWidget {
  const TaqaNewsPage({super.key, required this.items});

  final List<NewsItem> items;

  static const double _cardsTop = 149;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).locale.languageCode;
    final t = AppLocalizations.of(context).translate;
    final list = items;

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: TaqaUiScale.h(_cardsTop)),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  TaqaUiScale.w(20),
                  0,
                  TaqaUiScale.w(20),
                  TaqaUiScale.h(24),
                ),
                itemCount: list.isEmpty ? 1 : list.length,
                separatorBuilder: (_, _) => SizedBox(height: TaqaUiScale.h(12)),
                itemBuilder: (context, index) {
                  if (list.isEmpty) {
                    return SizedBox(
                      height: TaqaUiStyles.carouselCardHeight,
                      child: Center(
                        child: Text(
                          t("no_announcements"),
                          style: TaqaUiStyles.subtitle,
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: TaqaUiStyles.carouselCardHeight,
                    width: double.infinity,
                    child: _NewsCard(item: list[index], locale: locale),
                  );
                },
              ),
            ),
            Positioned(
              top: TaqaUiScale.h(43),
              left: TaqaUiScale.w(16),
              child: TaqaPageHeader(title: t("dash_news_tag")),
            ),
            const Positioned(top: 39, left: 8, child: TaqaBackButton()),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.locale});

  final NewsItem item;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final dateLabel = item.createdAt == null
        ? ''
        : DateFormat('EEE, MMMM d', locale).format(item.createdAt!.toLocal());
    final leftInset = TaqaUiScale.w(14);
    final cardWidth = TaqaUiStyles.carouselCardWidth;
    final dateTop = TaqaUiScale.h(8);
    final dateHeight = TaqaUiScale.h(10);
    final titleTop = TaqaUiScale.h(48);
    final titleHeight = TaqaUiScale.h(25);
    final descriptionTop = TaqaUiScale.h(72);
    final descriptionHeight = TaqaUiScale.h(36);

    return Material(
      color: Colors.transparent,
      borderRadius: TaqaUiStyles.carouselCardRadius,
      child: InkWell(
        borderRadius: TaqaUiStyles.carouselCardRadius,
        onTap: () => NewsTagActions.handleTagTap(context, item.tag, item: item),
        child: Ink(
          decoration: BoxDecoration(
            color: TaqaUiColors.charcoal,
            borderRadius: TaqaUiStyles.carouselCardRadius,
          ),
          child: Stack(
            children: [
              Positioned(
                left: leftInset,
                top: dateTop,
                width: math.max(0, cardWidth - (leftInset * 2)),
                height: dateHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dateLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TaqaUiStyles.carouselDate,
                  ),
                ),
              ),
              Positioned(
                left: leftInset,
                top: titleTop,
                width: math.min(
                  TaqaUiStyles.carouselContentWidth,
                  cardWidth - (leftInset * 2),
                ),
                height: titleHeight,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.carouselTitle,
                ),
              ),
              Positioned(
                left: leftInset,
                top: descriptionTop,
                width: math.min(
                  TaqaUiStyles.carouselContentWidth,
                  cardWidth - (leftInset * 2),
                ),
                height: descriptionHeight,
                child: Text(
                  item.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.carouselDescription,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
