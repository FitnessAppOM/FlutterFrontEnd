import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_intro_module.dart';

class TaqaPostPurchaseIntroPage extends StatefulWidget {
  const TaqaPostPurchaseIntroPage({
    super.key,
    this.module = TaqaIntroModule.dashboard,
    this.recordCompletion = true,
  });

  final TaqaIntroModule module;

  /// Settings replays tours without changing their one-time onboarding state.
  final bool recordCompletion;

  @override
  State<TaqaPostPurchaseIntroPage> createState() =>
      _TaqaPostPurchaseIntroPageState();
}

class _TaqaPostPurchaseIntroPageState extends State<TaqaPostPurchaseIntroPage> {
  bool _finishing = false;

  static const _dashboardSlides = <_TaqaIntroSlide>[
    _TaqaIntroSlide.screenshot(7, 1),
    _TaqaIntroSlide.screenshot(9, 2),
    _TaqaIntroSlide.screenshot(8, 3),
    _TaqaIntroSlide.screenshot(5, 4),
    _TaqaIntroSlide.screenshot(1, 10),
    _TaqaIntroSlide.screenshot(2, 11),
    _TaqaIntroSlide.screenshot(3, 12),
    _TaqaIntroSlide.screenshot(4, 13),
    _TaqaIntroSlide.text(
      'post_purchase_intro_dashboard_explore_title',
      'post_purchase_intro_dashboard_explore_body',
    ),
  ];

  static const _trainingSlides = <_TaqaIntroSlide>[
    _TaqaIntroSlide.screenshot(10, 5),
    _TaqaIntroSlide.screenshot(13, 6),
    _TaqaIntroSlide.screenshot(11, 7),
    _TaqaIntroSlide.screenshot(12, 8),
  ];

  static const _dietSlides = <_TaqaIntroSlide>[
    _TaqaIntroSlide.screenshot(6, 9),
    _TaqaIntroSlide.screenshot(17, 17),
  ];

  static const _communitySlides = <_TaqaIntroSlide>[
    _TaqaIntroSlide.screenshot(14, 14),
    _TaqaIntroSlide.screenshot(16, 16),
    _TaqaIntroSlide.screenshot(15, 15),
    _TaqaIntroSlide.screenshot(18, 18),
  ];

  static const _clientCoachSlides = <_TaqaIntroSlide>[
    _TaqaIntroSlide.screenshot(19, 19),
    _TaqaIntroSlide.screenshot(21, 21),
    _TaqaIntroSlide.screenshot(20, 20),
  ];

  static const _expertCoachSlides = <_TaqaIntroSlide>[
    _TaqaIntroSlide.screenshot(22, 22),
    _TaqaIntroSlide.screenshot(24, 24),
    _TaqaIntroSlide.screenshot(23, 23),
    _TaqaIntroSlide.screenshot(25, 25),
    _TaqaIntroSlide.screenshot(26, 26),
  ];

  List<_TaqaIntroSlide> get _slides => switch (widget.module) {
    TaqaIntroModule.dashboard => _dashboardSlides,
    TaqaIntroModule.diet => _dietSlides,
    TaqaIntroModule.training => _trainingSlides,
    TaqaIntroModule.community => _communitySlides,
    TaqaIntroModule.clientCoach => _clientCoachSlides,
    TaqaIntroModule.expertCoach => _expertCoachSlides,
  };

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    if (widget.recordCompletion) {
      await AccountStorage.completePostPurchaseIntroModule(
        widget.module.storageKey,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titleStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(26),
      fontWeight: FontWeight.w700,
      height: 1.05,
      color: TaqaUiColors.charcoal,
    );
    final bodyStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(15),
      fontWeight: FontWeight.w300,
      height: 1.25,
      color: TaqaUiColors.charcoal,
    );
    final pageDecoration = PageDecoration(
      pageColor: TaqaUiColors.lightGray,
      titleTextStyle: titleStyle,
      bodyTextStyle: bodyStyle,
      imageFlex: 9,
      bodyFlex: 2,
      imageAlignment: Alignment.bottomCenter,
      bodyAlignment: Alignment.topCenter,
      imagePadding: EdgeInsets.fromLTRB(
        TaqaUiScale.w(28),
        TaqaUiScale.h(18),
        TaqaUiScale.w(28),
        0,
      ),
      contentMargin: EdgeInsets.symmetric(horizontal: TaqaUiScale.w(28)),
      titlePadding: EdgeInsets.only(
        top: TaqaUiScale.h(12),
        bottom: TaqaUiScale.h(8),
      ),
      bodyPadding: EdgeInsets.zero,
      pageMargin: EdgeInsets.only(bottom: TaqaUiScale.h(66)),
      safeArea: TaqaUiScale.h(66),
    );
    final slides = _slides;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TaqaUiColors.lightGray,
        body: IntroductionScreen(
          globalBackgroundColor: TaqaUiColors.lightGray,
          pages: slides
              .map((slide) => _buildPage(slide, pageDecoration, t))
              .toList(growable: false),
          onDone: _finish,
          onSkip: _finish,
          showSkipButton: slides.length > 1,
          showBackButton: false,
          allowImplicitScrolling: true,
          isProgressTap: true,
          curve: Curves.easeOutCubic,
          animationDuration: 320,
          safeAreaList: const [true, true, true, true],
          skipOrBackFlex: 1,
          dotsFlex: 2,
          nextFlex: 2,
          controlsMargin: EdgeInsets.fromLTRB(
            TaqaUiScale.w(16),
            0,
            TaqaUiScale.w(16),
            TaqaUiScale.h(10),
          ),
          controlsPadding: EdgeInsets.symmetric(
            horizontal: TaqaUiScale.w(8),
            vertical: TaqaUiScale.h(5),
          ),
          baseBtnStyle: TextButton.styleFrom(
            foregroundColor: TaqaUiColors.charcoal,
            padding: EdgeInsets.symmetric(
              horizontal: TaqaUiScale.w(8),
              vertical: TaqaUiScale.h(10),
            ),
            shape: RoundedRectangleBorder(borderRadius: TaqaUiScale.radius(5)),
          ),
          doneStyle: TextButton.styleFrom(
            foregroundColor: TaqaUiColors.charcoal,
            backgroundColor: TaqaUiColors.lime,
            padding: EdgeInsets.symmetric(
              horizontal: TaqaUiScale.w(10),
              vertical: TaqaUiScale.h(12),
            ),
            shape: RoundedRectangleBorder(borderRadius: TaqaUiScale.radius(5)),
          ),
          skip: Text(
            t.translate('post_purchase_intro_skip').toUpperCase(),
            style: _controlTextStyle,
          ),
          next: Icon(Icons.arrow_forward_rounded, size: TaqaUiScale.w(24)),
          done: _finishing
              ? SizedBox(
                  width: TaqaUiScale.w(18),
                  height: TaqaUiScale.h(18),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TaqaUiColors.charcoal,
                  ),
                )
              : Text(
                  t.translate('post_purchase_intro_done').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: _controlTextStyle,
                ),
          dotsDecorator: DotsDecorator(
            size: Size(TaqaUiScale.w(5), TaqaUiScale.h(5)),
            activeSize: Size(TaqaUiScale.w(18), TaqaUiScale.h(5)),
            spacing: EdgeInsets.symmetric(horizontal: TaqaUiScale.w(2)),
            color: TaqaUiColors.charcoal.withValues(alpha: 0.22),
            activeColor: TaqaUiColors.charcoal,
            activeShape: RoundedRectangleBorder(
              borderRadius: TaqaUiScale.radius(5),
            ),
          ),
        ),
      ),
    );
  }

  PageViewModel _buildPage(
    _TaqaIntroSlide slide,
    PageDecoration decoration,
    AppLocalizations t,
  ) {
    if (slide.assetIndex != null && slide.copyIndex != null) {
      return PageViewModel(
        title: t.translate('post_purchase_intro_${slide.copyIndex}_title'),
        body: t.translate('post_purchase_intro_${slide.copyIndex}_body'),
        image: _TaqaIntroScreenshot(assetIndex: slide.assetIndex!),
        decoration: decoration,
      );
    }
    return PageViewModel(
      titleWidget: const SizedBox.shrink(),
      bodyWidget: const SizedBox.shrink(),
      image: _TaqaIntroTextPanel(
        module: widget.module,
        title: t.translate(slide.titleKey!),
        body: t.translate(slide.bodyKey!),
      ),
      decoration: decoration,
    );
  }

  TextStyle get _controlTextStyle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(11),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
  );
}

class _TaqaIntroSlide {
  const _TaqaIntroSlide.screenshot(this.assetIndex, this.copyIndex)
    : titleKey = null,
      bodyKey = null;

  const _TaqaIntroSlide.text(this.titleKey, this.bodyKey)
    : assetIndex = null,
      copyIndex = null;

  final int? assetIndex;
  final int? copyIndex;
  final String? titleKey;
  final String? bodyKey;
}

class _TaqaIntroScreenshot extends StatelessWidget {
  const _TaqaIntroScreenshot({required this.assetIndex});

  final int assetIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: TaqaUiScale.w(286)),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(14),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: TaqaUiColors.charcoal.withValues(alpha: 0.14),
            blurRadius: TaqaUiScale.w(16),
            offset: Offset(0, TaqaUiScale.h(7)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: TaqaUiScale.radius(14),
        child: Image.asset(
          'assets/images/post_purchase_intro_$assetIndex.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _TaqaIntroTextPanel extends StatelessWidget {
  const _TaqaIntroTextPanel({
    required this.module,
    required this.title,
    required this.body,
  });

  final TaqaIntroModule module;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: TaqaUiScale.w(330),
        minHeight: TaqaUiScale.h(430),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: TaqaUiScale.w(28),
        vertical: TaqaUiScale.h(36),
      ),
      decoration: BoxDecoration(
        color: TaqaUiColors.charcoal,
        borderRadius: TaqaUiScale.radius(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: TaqaUiScale.w(64),
            height: TaqaUiScale.w(64),
            padding: EdgeInsets.all(TaqaUiScale.w(17)),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: TaqaUiColors.lime,
            ),
            child: SvgPicture.asset(
              module.iconAssetPath,
              colorFilter: const ColorFilter.mode(
                TaqaUiColors.charcoal,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(30)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(42),
              fontWeight: FontWeight.w700,
              height: 0.98,
              color: TaqaUiColors.white,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(18)),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(17),
              fontWeight: FontWeight.w300,
              height: 1.3,
              color: TaqaUiColors.lightGray,
            ),
          ),
        ],
      ),
    );
  }
}
