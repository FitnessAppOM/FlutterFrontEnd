import 'package:flutter/material.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../localization/app_localizations.dart';

class ExpertSubmissionSuccessPage extends StatelessWidget {
  const ExpertSubmissionSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TaqaUiColors.white,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: TaqaUiColors.unnamedColor1c1d17),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          t.translate("expert_submission_title"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 25 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        backgroundColor: TaqaUiColors.white,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.translate("expert_submission_body"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w400,
                      height: 12 / 10,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(25)),
                  Text(
                    t.translate("expert_submission_next_steps"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(11)),
                  Text(
                    "+ ${t.translate("expert_submission_step_review")}\n"
                    "+ ${t.translate("expert_submission_step_notify")}\n"
                    "+ ${t.translate("expert_submission_step_dashboard")}",
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w400,
                      height: 20 / 15,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 0, 16, 20),
            child: TaqaFilledButton(
              label: t.translate("close"),
              onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
        ],
      ),
    );
  }
}
