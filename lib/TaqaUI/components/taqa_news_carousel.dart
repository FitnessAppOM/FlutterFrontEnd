import 'dart:async';

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_layout.dart';
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
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            height: 143,
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: slide.onTap,
        child: Ink(
          padding: TaqaUiLayout.carouselContentPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TaqaUiColors.charcoal, TaqaUiColors.charcoal],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.dateLabel.toUpperCase(),
                style: const TextStyle(
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: 8,
                  fontWeight: FontWeight.w400,
                  color: TaqaUiColors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slide.title,
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
                  slide.subtitle,
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
              const SizedBox(height: 8),
              Row(
                children: List.generate(indicatorCount, (i) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: i == indicatorCount - 1 ? 0 : 12,
                      ),
                      height: 2,
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
            ],
          ),
        ),
      ),
    );
  }
}
