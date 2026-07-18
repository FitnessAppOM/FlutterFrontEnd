import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/daily_outlook/daily_outlook_service.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaDailyOutlookDetailPage extends StatelessWidget {
  const TaqaDailyOutlookDetailPage({super.key, required this.outlook});

  final DailyOutlookData outlook;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final generatedTag = outlook.readinessState.trim().isNotEmpty
        ? outlook.readinessState.trim()
        : t('dash_daily_outlook_title');
    final bodyStyle = TaqaUiStyles.dailyOutlookDescription;
    final headlineStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(25),
      fontWeight: FontWeight.w700,
      color: TaqaUiColors.charcoal,
      letterSpacing: 0,
      height: 1,
    );

    return Scaffold(
      backgroundColor: TaqaUiColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: TaqaUiScale.insetsLTRB(16, 12, 16, 0),
                children: [
                  SizedBox(
                    height: TaqaUiScale.h(40),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            splashRadius: TaqaUiScale.w(20),
                            icon: Icon(
                              Directionality.of(context) == TextDirection.rtl
                                  ? Icons.arrow_forward_ios
                                  : Icons.arrow_back_ios_new,
                              color: TaqaUiColors.charcoal,
                              size: TaqaUiScale.w(18),
                            ),
                          ),
                        ),
                        Text(
                          t('dash_daily_outlook_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TaqaUiStyles.pageTitle.copyWith(
                            color: TaqaUiColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(42)),
                  Text(
                    generatedTag.toUpperCase(),
                    textAlign: TextAlign.start,
                    style: TaqaUiStyles.dailyOutlookTag,
                  ),
                  SizedBox(height: TaqaUiScale.h(21)),
                  Text(
                    outlook.headline,
                    textAlign: TextAlign.start,
                    style: headlineStyle,
                  ),
                  SizedBox(height: TaqaUiScale.h(15)),
                  SizedBox(
                    width: TaqaUiScale.w(357),
                    child: Text(
                      outlook.summary,
                      textAlign: TextAlign.start,
                      style: bodyStyle,
                    ),
                  ),
                  if (outlook.actionItems.isNotEmpty) ...[
                    SizedBox(height: TaqaUiScale.h(14)),
                    ...outlook.actionItems.map(
                      (item) => Padding(
                        padding: EdgeInsetsDirectional.only(
                          bottom: TaqaUiScale.h(8),
                        ),
                        child: Text(
                          '- $item',
                          textAlign: TextAlign.start,
                          style: bodyStyle,
                        ),
                      ),
                    ),
                  ],
                  if (outlook.cautionNote.trim().isNotEmpty) ...[
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      outlook.cautionNote,
                      textAlign: TextAlign.start,
                      style: bodyStyle,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: TaqaUiScale.insetsLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: TaqaUiScale.h(45),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: TaqaUiColors.lime,
                    foregroundColor: TaqaUiColors.charcoal,
                    shape: RoundedRectangleBorder(
                      borderRadius: TaqaUiStyles.actionButtonRadius,
                    ),
                  ),
                  child: Text(
                    t('okay'),
                    textAlign: TextAlign.center,
                    style: TaqaUiStyles.dailyOutlookButton,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
