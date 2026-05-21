import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/styles/taqa_ui_styles.dart';
import '../localization/app_localizations.dart';
import '../models/news_item.dart';

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
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
                          style: const TextStyle(
                            fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                            fontSize: 8,
                            fontWeight: FontWeight.w400,
                            color: TaqaUiColors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      if (dateLabel.isNotEmpty) const SizedBox(height: 20),
                      Text(
                        item.title,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: TaqaUiColors.white,
                          height: 1.2,
                        ),
                      ),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: TaqaUiColors.white,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (item.contentUrl.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _PdfButton(url: item.contentUrl),
                      ],
                      const SizedBox(height: 18),
                      if (paragraphs.isEmpty)
                        const Text(
                          "No article content yet.",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: TaqaUiColors.lightGray,
                          ),
                        )
                      else
                        ...paragraphs.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              p,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: TaqaUiColors.white,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}

class _PdfButton extends StatelessWidget {
  final String url;

  const _PdfButton({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(url);
          await launchUrl(
            uri,
            mode: LaunchMode.inAppBrowserView,
          );
        },
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("Open PDF"),
        style: ElevatedButton.styleFrom(
          backgroundColor: TaqaUiColors.lime,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
