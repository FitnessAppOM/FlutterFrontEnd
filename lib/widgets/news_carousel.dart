import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class NewsSlide {
  final String title;
  final String subtitle;
  final String tag;
  final Color color;
  final VoidCallback? onTap;

  const NewsSlide({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color,
    this.onTap,
  });
}

class NewsCarousel extends StatefulWidget {
  const NewsCarousel({
    super.key,
    required this.slides,
  });

  final List<NewsSlide> slides;

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  PageController? _controller;
  int _index = 0;
  int _initialPage = 0;
  Timer? _timer;

  int _computeInitialPage(int length) => length > 0 ? length * 1000 : 0;

  @override
  void initState() {
    super.initState();
    _initialPage = _computeInitialPage(widget.slides.length);
    _controller = PageController(
      viewportFraction: 0.88,
      initialPage: _initialPage,
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _initialPage = _computeInitialPage(widget.slides.length);
      _controller?.dispose();
      _controller = PageController(
        viewportFraction: 0.88,
        initialPage: _initialPage,
      );
      _index = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.slides.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_controller == null || !mounted) return;
      final nextPage = (_controller!.page ?? _initialPage).round() + 1;
      _controller!.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty || _controller == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: null, // infinite scroll
            onPageChanged: (i) {
              if (!mounted || slides.isEmpty) return;
              setState(() => _index = i % slides.length);
            },
            itemBuilder: (context, i) {
              final realIndex = slides.isEmpty ? 0 : i % slides.length;
              final slide = slides[realIndex];
              return _SlideCard(
                slide: slide,
                isFocused: realIndex == _index,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.isFocused,
  });

  final NewsSlide slide;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = slide.color;
    final edgeColor = const Color(0xFFD4AF37).withValues(alpha: 0.18);
    final rotation = isFocused ? 0.0 : (Random().nextBool() ? 0.004 : -0.004);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: isFocused ? 1 : 0.94),
      duration: const Duration(milliseconds: 260),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: slide.onTap,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.9),
                        cs.surfaceVariant.withValues(alpha: 0.35),
                      ],
                    ),
                    border: Border.all(color: edgeColor),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          slide.tag,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        slide.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        slide.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
