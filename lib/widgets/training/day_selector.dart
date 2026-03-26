import 'dart:math' as math;

import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<bool> completed;
  final List<bool> worked;
  final List<bool> disabled;
  final List<String?> notes;
  final bool workoutInProgress;
  final int? workoutInProgressIndex;

  const DaySelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.completed = const [],
    this.worked = const [],
    this.disabled = const [],
    this.notes = const [],
    this.workoutInProgress = false,
    this.workoutInProgressIndex,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const completedGradient = LinearGradient(
      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
    );
    final hasNotes = notes.any((n) => n != null && n.trim().isNotEmpty);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SizedBox(
        height: hasNotes ? 58 : 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: labels.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final selected = i == selectedIndex;
            final isCompleted = i < completed.length ? completed[i] : false;
            final isWorked = i < worked.length ? worked[i] : false;
            final isGreenState = isCompleted || isWorked;
            final isDisabled = i < disabled.length ? disabled[i] : false;
            final note = i < notes.length ? notes[i] : null;
            final showWorkoutGlow =
                workoutInProgress &&
                workoutInProgressIndex != null &&
                i == workoutInProgressIndex &&
                !isDisabled;
            return GestureDetector(
              onTap: isDisabled ? null : () => onSelect(i),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: showWorkoutGlow
                          ? const LinearGradient(
                              colors: [Color(0xFF251A0B), Color(0xFF120D08)],
                            )
                          : (selected && !isDisabled)
                          ? (isGreenState
                                ? completedGradient
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF2D8CFF),
                                      Color(0xFF5E5CFF),
                                    ],
                                  ))
                          : null,
                      color: isDisabled
                          ? Colors.white.withOpacity(0.05)
                          : (selected
                                ? null
                                : (isGreenState
                                      ? const Color(
                                          0xFF2ECC71,
                                        ).withOpacity(0.18)
                                      : Colors.white.withOpacity(0.08))),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDisabled
                            ? Colors.white.withOpacity(0.18)
                            : showWorkoutGlow
                            ? const Color(0xFFFFC870).withOpacity(0.75)
                            : (isGreenState
                                  ? const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(selected ? 0.9 : 0.6)
                                  : Colors.white.withOpacity(0.18)),
                      ),
                      boxShadow: selected
                          ? (isDisabled
                                ? null
                                : [
                                    BoxShadow(
                                      color:
                                          (showWorkoutGlow
                                                  ? const Color(0xFFFFB347)
                                                  : (isGreenState
                                                        ? const Color(
                                                            0xFF2ECC71,
                                                          )
                                                        : cs.primary))
                                              .withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ])
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: isDisabled
                                ? Colors.white54
                                : showWorkoutGlow
                                ? const Color(0xFFFFE6B0)
                                : (selected
                                      ? Colors.white
                                      : (isGreenState
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.8))),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (note != null && note.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            note,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: showWorkoutGlow
                                  ? const Color(0xFFFFD68A).withOpacity(0.85)
                                  : Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showWorkoutGlow)
                    const Positioned.fill(
                      child: IgnorePointer(child: _DaySnakeEdgeGlow()),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DaySnakeEdgeGlow extends StatefulWidget {
  const _DaySnakeEdgeGlow();

  @override
  State<_DaySnakeEdgeGlow> createState() => _DaySnakeEdgeGlowState();
}

class _DaySnakeEdgeGlowState extends State<_DaySnakeEdgeGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _DaySnakeEdgeGlowPainter(progress: _controller.value),
        ),
      ),
    );
  }
}

class _DaySnakeEdgeGlowPainter extends CustomPainter {
  const _DaySnakeEdgeGlowPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      const Radius.circular(14),
    );
    final inner = outer.deflate(2.2);

    final ringPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outer),
      Path()..addRRect(inner),
    );

    final sweep = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(2 * math.pi * progress),
      colors: const [
        Color(0x00000000),
        Color(0x00000000),
        Color(0x1AFFA733),
        Color(0x80FFBB55),
        Color(0xFFFFE49A),
        Color(0xB3FFBB55),
        Color(0x33FFA733),
        Color(0x00000000),
      ],
      stops: const [0.0, 0.57, 0.70, 0.78, 0.84, 0.90, 0.96, 1.0],
    );
    final shader = sweep.createShader(rect);

    final fillPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;
    canvas.drawPath(ringPath, fillPaint);

    final glowPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawRRect(outer.deflate(0.8), glowPaint);
  }

  @override
  bool shouldRepaint(covariant _DaySnakeEdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
