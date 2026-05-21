import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_layout.dart';
import '../styles/taqa_ui_styles.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/news_item.dart';
import '../../../services/news/news_tag_actions.dart';

class TaqaNewsPage extends StatelessWidget {
  const TaqaNewsPage({super.key, required this.items});

  final List<NewsItem> items;

  static const double _cardsTop = 94;
  static const double _cardHeight = 143;
  static const double _cardRadius = 28;
  static const double _cardGap = 12;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).locale.languageCode;
    final t = AppLocalizations.of(context).translate;
    final list = items;

    final titleStyle = TaqaUiStyles.pageTitle.copyWith(
      color: TaqaUiColors.charcoal,
    );

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _cardsTop),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: list.isEmpty ? 1 : list.length,
                separatorBuilder: (_, _) => const SizedBox(height: _cardGap),
                itemBuilder: (context, index) {
                  if (list.isEmpty) {
                    return SizedBox(
                      height: _cardHeight,
                      child: Center(
                        child: Text(
                          t("no_announcements"),
                          style: const TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: TaqaUiColors.charcoal,
                          ),
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: _cardHeight,
                    width: double.infinity,
                    child: _NewsCard(item: list[index], locale: locale),
                  );
                },
              ),
            ),
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(t("dash_news_tag"), style: titleStyle),
              ),
            ),
            const Positioned(
              top: 20,
              left: 8,
              child: _BackButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      splashRadius: 20,
      icon: const Icon(
        Icons.arrow_back_ios_new,
        color: TaqaUiColors.charcoal,
        size: 18,
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(TaqaNewsPage._cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(TaqaNewsPage._cardRadius),
        onTap: () => NewsTagActions.handleTagTap(context, item.tag, item: item),
        child: Ink(
          decoration: BoxDecoration(
            color: TaqaUiColors.unnamedColor1c1d17,
            borderRadius: BorderRadius.circular(TaqaNewsPage._cardRadius),
          ),
          padding: TaqaUiLayout.carouselContentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: 8,
                  fontWeight: FontWeight.w400,
                  color: TaqaUiColors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        color: TaqaUiColors.white,
                        height: 1.25,
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
  }
}
