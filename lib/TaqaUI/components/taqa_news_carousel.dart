import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class NewsSlide {
  final String title;
  final String subtitle;
  final String dateLabel;
  final Color color;
  final VoidCallback? onTap;

  const NewsSlide({
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.color,
    this.onTap,
  });
}

class NewsCarousel extends StatefulWidget {
  const NewsCarousel({super.key, required this.slides});

  final List<NewsSlide> slides;

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prevLen = oldWidget.slides.length;
    final nextLen = widget.slides.length;
    if (prevLen != nextLen) {
      if (nextLen == 0) {
        _index = 0;
      } else if (_index >= nextLen) {
        _index = _index % nextLen;
      }
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.slides.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.slides.isEmpty) return;
      _goNext();
    });
  }

  void _goNext() {
    if (widget.slides.isEmpty) return;
    setState(() => _index = (_index + 1) % widget.slides.length);
  }

  void _goPrev() {
    if (widget.slides.isEmpty) return;
    final len = widget.slides.length;
    setState(() => _index = (_index - 1 + len) % len);
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity.abs() < 120) return;
    if (velocity < 0) {
      _goNext();
    } else {
      _goPrev();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    final activeIndex = _index % slides.length;
    final activeSlide = slides[activeIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.carouselCardWidth,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: cardWidth,
            height: TaqaUiStyles.carouselCardHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: _handleSwipe,
              child: _SlideCard(
                slide: activeSlide,
                activeIndex: activeIndex,
                slideCount: slides.length,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.activeIndex,
    required this.slideCount,
  });

  final NewsSlide slide;
  final int activeIndex;
  final int slideCount;

  @override
  Widget build(BuildContext context) {
    final indicatorCount = slideCount <= 0 ? 1 : slideCount;
    final safeActive = activeIndex % indicatorCount;
    final cardWidth = TaqaUiStyles.carouselCardWidth;
    final leftInset = TaqaUiScale.w(14);
    final dateTop = TaqaUiScale.h(8);
    final dateHeight = TaqaUiScale.h(10);
    final titleTop = TaqaUiScale.h(48);
    final titleHeight = TaqaUiScale.h(32);
    final descriptionTop = TaqaUiScale.h(72);
    final indicatorBottom = TaqaUiScale.h(10);
    final indicatorHeight = TaqaUiScale.h(2);
    final indicatorGap = TaqaUiScale.w(12);
    final titleBottomGap = TaqaUiScale.h(4);
    final descriptionBottomGap = TaqaUiScale.h(8);
    final indicatorTop = TaqaUiStyles.carouselCardHeight - indicatorBottom - indicatorHeight;
    final descriptionHeight = math.max(
      TaqaUiScale.h(36),
      indicatorTop - descriptionTop - descriptionBottomGap,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: TaqaUiStyles.carouselCardRadius,
      child: InkWell(
        borderRadius: TaqaUiStyles.carouselCardRadius,
        onTap: slide.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: TaqaUiColors.charcoal,
            borderRadius: TaqaUiStyles.carouselCardRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TaqaUiColors.charcoal, TaqaUiColors.charcoal],
            ),
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
                    slide.dateLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TaqaUiStyles.carouselDate,
                  ),
                ),
              ),
              Positioned(
                left: leftInset,
                top: titleTop,
                width: math.max(0, cardWidth - (leftInset * 2)),
                height: titleHeight,
                child: Text(
                  slide.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.carouselTitle,
                ),
              ),
              Positioned(
                left: leftInset,
                top: math.max(descriptionTop, titleTop + titleHeight + titleBottomGap),
                width: math.min(
                  TaqaUiStyles.carouselContentWidth,
                  cardWidth - (leftInset * 2),
                ),
                height: descriptionHeight,
                child: Text(
                  slide.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.carouselDescription,
                ),
              ),
              Positioned(
                left: leftInset,
                right: leftInset,
                bottom: indicatorBottom,
                height: indicatorHeight,
                child: Row(
                  children: List.generate(indicatorCount, (i) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: i == indicatorCount - 1 ? 0 : indicatorGap,
                        ),
                        height: indicatorHeight,
                        decoration: BoxDecoration(
                          color: i == safeActive
                              ? TaqaUiColors.lightGray
                              : TaqaUiColors.graphite,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
