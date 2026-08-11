import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../localization/app_localizations.dart';
import '../Typography/taqa_ui_typography.dart';
import '../components/taqa_page_app_bar.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_intro_module.dart';
import 'taqa_post_purchase_intro_page.dart';

class TaqaTutorialLibraryPage extends StatelessWidget {
  const TaqaTutorialLibraryPage({super.key});

  static const _modules = <TaqaIntroModule>[
    TaqaIntroModule.dashboard,
    TaqaIntroModule.diet,
    TaqaIntroModule.training,
    TaqaIntroModule.community,
    TaqaIntroModule.clientCoach,
    TaqaIntroModule.expertCoach,
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TaqaUiColors.lightGray,
      appBar: TaqaPageAppBar(title: t.translate('settings_taqa_tutorial')),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            TaqaUiScale.w(18),
            TaqaUiScale.h(18),
            TaqaUiScale.w(18),
            TaqaUiScale.h(32),
          ),
          itemCount: _modules.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: TaqaUiScale.h(10)),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: EdgeInsets.only(
                  left: TaqaUiScale.w(4),
                  right: TaqaUiScale.w(4),
                  bottom: TaqaUiScale.h(8),
                ),
                child: Text(
                  t.translate('taqa_tutorial_library_body'),
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w300,
                    height: 1.3,
                    color: TaqaUiColors.charcoal,
                  ),
                ),
              );
            }
            final module = _modules[index - 1];
            return _TutorialModuleCard(
              module: module,
              title: t.translate(module.titleKey),
              description: t.translate(module.descriptionKey),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => TaqaPostPurchaseIntroPage(
                    module: module,
                    recordCompletion: false,
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

class _TutorialModuleCard extends StatelessWidget {
  const _TutorialModuleCard({
    required this.module,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final TaqaIntroModule module;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(15),
        child: Padding(
          padding: EdgeInsets.all(TaqaUiScale.w(15)),
          child: Row(
            children: [
              Container(
                width: TaqaUiScale.w(46),
                height: TaqaUiScale.w(46),
                padding: EdgeInsets.all(TaqaUiScale.w(12)),
                decoration: BoxDecoration(
                  color: TaqaUiColors.lime,
                  borderRadius: TaqaUiScale.radius(12),
                ),
                child: SvgPicture.asset(
                  module.iconAssetPath,
                  colorFilter: const ColorFilter.mode(
                    TaqaUiColors.charcoal,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(16),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(3)),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(12),
                        fontWeight: FontWeight.w300,
                        height: 1.2,
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: TaqaUiScale.w(8)),
              Icon(
                Icons.chevron_right_rounded,
                size: TaqaUiScale.w(22),
                color: TaqaUiColors.charcoal.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
