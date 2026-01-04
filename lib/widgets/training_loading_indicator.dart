import 'dart:math' as math;
import 'package:flutter/material.dart';

class TrainingLoadingIndicator extends StatefulWidget {
  const TrainingLoadingIndicator({super.key, this.size = 140});

  final double size;

  @override
  State<TrainingLoadingIndicator> createState() => _TrainingLoadingIndicatorState();
}

class _TrainingLoadingIndicatorState extends State<TrainingLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 0,
                      endAngle: 2 * math.pi,
                      colors: [
                        cs.primary.withOpacity(0.05),
                        cs.primary.withOpacity(0.35),
                        cs.secondary.withOpacity(0.45),
                        cs.primary.withOpacity(0.05),
                      ],
                      stops: const [0.0, 0.4, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
              Container(
                width: widget.size * 0.72,
                height: widget.size * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: cs.primary,
                  size: widget.size * 0.28,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
