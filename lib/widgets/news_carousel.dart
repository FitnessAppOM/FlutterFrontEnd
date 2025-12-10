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
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final slide = slides[i];
              return _SlideCard(
                slide: slide,
                isFocused: i == _index,
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
                        accent.withValues(alpha: 0.85),
                        cs.surfaceVariant.withValues(alpha: 0.4),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
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
