import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/styles/taqa_ui_styles.dart';
import '../localization/app_localizations.dart';
import '../models/news_item.dart';
import 'pdf_viewer_page.dart';

class ArticlePage extends StatelessWidget {
  final NewsItem item;

  const ArticlePage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).locale.languageCode;
    final useContent = item.content.isNotEmpty;
    final bodyText = (useContent ? item.content : item.subtitle).trim();
    final paragraphs = bodyText.isEmpty
        ? const <String>[]
        : bodyText
            .split(RegExp(r'\n\s*\n'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
    final dateLabel = item.createdAt == null
        ? ''
        : DateFormat('EEE, MMMM d', locale).format(item.createdAt!.toLocal());

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColor1c1d17,
      appBar: AppBar(
        backgroundColor: TaqaUiColors.unnamedColor1c1d17,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "News",
          style: TaqaUiStyles.pageTitle.copyWith(
            color: TaqaUiColors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateLabel.isNotEmpty)
                          Text(
                            dateLabel.toUpperCase(),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                              fontSize: TaqaUiScale.sp(8),
                              fontWeight: FontWeight.w400,
                              color: TaqaUiColors.white,
                              letterSpacing: 0,
                              height: 10 / 8,
                            ),
                          ),
                        if (dateLabel.isNotEmpty) SizedBox(height: TaqaUiScale.h(21)),
                        Text(
                          item.title,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(25),
                            fontWeight: FontWeight.w700,
                            color: TaqaUiColors.white,
                            height: 1,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          SizedBox(height: TaqaUiScale.h(5)),
                          Text(
                            item.subtitle,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(15),
                              fontWeight: FontWeight.w400,
                              color: TaqaUiColors.white,
                              height: 13 / 15,
                            ),
                          ),
                        ],
                        SizedBox(height: TaqaUiScale.h(15)),
                        if (paragraphs.isEmpty)
                          Text(
                            "No article content yet.",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(10),
                              fontWeight: FontWeight.w400,
                              color: TaqaUiColors.lightGray,
                            ),
                          )
                        else
                          ...paragraphs.map(
                            (p) => Padding(
                              padding: EdgeInsets.only(bottom: TaqaUiScale.h(14)),
                              child: Text(
                                p,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(10),
                                  fontWeight: FontWeight.w400,
                                  color: TaqaUiColors.white,
                                  height: 12 / 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (item.contentUrl.isNotEmpty)
              Padding(
                padding: TaqaUiScale.insetsLTRB(16, 0, 16, 30),
                child: _PdfButton(url: item.contentUrl, title: item.title),
              ),
          ],
        ),
      ),
    );
  }

}

class _PdfButton extends StatelessWidget {
  final String url;
  final String title;

  const _PdfButton({required this.url, this.title = 'Document'});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.lime,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PdfViewerPage(url: url, title: title),
            ),
          );
        },
        child: SizedBox(
          width: TaqaUiScale.w(357),
          height: TaqaUiScale.h(45),
          child: Center(
            child: Text(
              "OPEN PDF",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w600,
                color: TaqaUiColors.unnamedColor1c1d17,
                letterSpacing: 0,
                height: 12 / 10,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
