import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/news_item.dart';
import '../../../services/news/news_tag_actions.dart';
import '../../../theme/app_theme.dart';

class TaqaNewsPage extends StatelessWidget {
  const TaqaNewsPage({super.key, required this.items});

  final List<NewsItem> items;

  static const double _cardsTop = 94;
  static const double _cardLeft = 16;
  static const double _cardHeight = 119;
  static const double _cardWidth = 357;
  static const double _cardRadius = 15;
  static const double _cardGap = 12;
  static const double _titleTop = 24;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).locale.languageCode;
    final t = AppLocalizations.of(context).translate;
    final list = items;

    final titleStyle = const TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: TaqaUiColors.white,
    );

    return Scaffold(
      backgroundColor: AppColors.cardDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (list.isEmpty) {
              return Stack(
                children: [
                  Positioned(
                    top: _titleTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(t("dash_news_tag"), style: titleStyle),
                    ),
                  ),
                  const Positioned(
                    top: _titleTop - 4,
                    left: 8,
                    child: _BackButton(),
                  ),
                  Center(
                    child: Text(
                      t("no_announcements"),
                      style: const TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: TaqaUiColors.white,
                      ),
                    ),
                  ),
                ],
              );
            }

            final cardWidth = math.min(
              _cardWidth,
              math.max(0.0, constraints.maxWidth - (_cardLeft * 2)),
            );
            final contentHeight =
                _cardsTop +
                (list.length * _cardHeight) +
                ((list.length - 1) * _cardGap) +
                24;

            return SingleChildScrollView(
              child: SizedBox(
                height: contentHeight,
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    Positioned(
                      top: _titleTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(t("dash_news_tag"), style: titleStyle),
                      ),
                    ),
                    const Positioned(
                      top: _titleTop - 4,
                      left: 8,
                      child: _BackButton(),
                    ),
                    for (int i = 0; i < list.length; i++)
                      Positioned(
                        top: _cardsTop + (i * (_cardHeight + _cardGap)),
                        left: _cardLeft,
                        width: cardWidth.toDouble(),
                        height: _cardHeight,
                        child: _NewsCard(item: list[i], locale: locale),
                      ),
                  ],
                ),
              ),
            );
          },
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
      icon: const Icon(Icons.arrow_back_ios_new, color: TaqaUiColors.white, size: 18),
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
            color: const Color(0xFF1C1D17),
            borderRadius: BorderRadius.circular(TaqaNewsPage._cardRadius),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
              const SizedBox(height: 8),
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
              Expanded(
                child: Text(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
