import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaPostPurchaseIntroPage extends StatefulWidget {
  const TaqaPostPurchaseIntroPage({super.key});

  @override
  State<TaqaPostPurchaseIntroPage> createState() =>
      _TaqaPostPurchaseIntroPageState();
}

class _TaqaPostPurchaseIntroPageState extends State<TaqaPostPurchaseIntroPage> {
  bool _finishing = false;

  static const List<_TaqaIntroSlide> _slides = [
    _TaqaIntroSlide(7, 1),
    _TaqaIntroSlide(9, 2),
    _TaqaIntroSlide(8, 3),
    _TaqaIntroSlide(5, 4),
    _TaqaIntroSlide(10, 5),
    _TaqaIntroSlide(13, 6),
    _TaqaIntroSlide(11, 7),
    _TaqaIntroSlide(12, 8),
    _TaqaIntroSlide(6, 9),
    _TaqaIntroSlide(1, 10),
    _TaqaIntroSlide(2, 11),
    _TaqaIntroSlide(3, 12),
    _TaqaIntroSlide(4, 13),
  ];

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await AccountStorage.completePostPurchaseIntro();
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TaqaUiColors.lightGray,
        body: IntroductionScreen(
          globalBackgroundColor: TaqaUiColors.lightGray,
          pages: _slides
              .map(
                (slide) => PageViewModel(
                  title: t.translate(
                    'post_purchase_intro_${slide.copyIndex}_title',
                  ),
                  body: t.translate(
                    'post_purchase_intro_${slide.copyIndex}_body',
                  ),
                  image: _TaqaIntroScreenshot(assetIndex: slide.assetIndex),
                  decoration: pageDecoration,
                ),
              )
              .toList(growable: false),
          onDone: _finish,
          onSkip: _finish,
          showSkipButton: true,
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

  TextStyle get _controlTextStyle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(11),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
  );
}

class _TaqaIntroSlide {
  const _TaqaIntroSlide(this.assetIndex, this.copyIndex);

  final int assetIndex;
  final int copyIndex;
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
