import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/training/training_service.dart';
import '../../services/training/training_reset_coordinator.dart';

class ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onTap;
  final VoidCallback onReplace;
  final bool disabled;
  final bool inProgress;
  final bool forceCompleted;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    required this.onReplace,
    this.disabled = false,
    this.inProgress = false,
    this.forceCompleted = false,
  });

  Map<String, dynamic>? _extractCompliance(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _valueAsText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      if (value == 0) return null;
      final asInt = value.toInt();
      return (value == asInt) ? asInt.toString() : value.toString();
    }
    if (value is bool) return value ? "1" : null;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    String _lower(dynamic v) => (v ?? '').toString().trim().toLowerCase();
    final category = _lower(exercise['category']);
    final exType = _lower(exercise['exercise_type']);
    final animName = _lower(exercise['animation_name']);
    final name = _lower(exercise['exercise_name']);
    final isCardio =
        [category, exType, animName, name].any((v) => v.contains('cardio')) ||
        animName.startsWith('cardio -');

    DateTime? _parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      if (value is num) {
        final intVal = value.toInt();
        // Accept both seconds and milliseconds since epoch.
        if (intVal > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(intVal);
        }
        if (intVal > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
        }
      }
      return null;
    }

    final resetNow = TrainingResetCoordinator.currentNowUtc();
    final DateTime _weekStart = TrainingResetCoordinator.weekStartMonday(
      resetNow,
    );
    final DateTime _weekEnd = TrainingResetCoordinator.weekEndSunday(resetNow);
    final Map<String, dynamic>? compliance =
        _extractCompliance(exercise['program_compliance']) ??
        _extractCompliance(exercise['compliance']);
    DateTime? _completionDateForExercise(Map<String, dynamic> ex) {
      final candidates = [
        ex['logged_at'],
        ex['completed_at'],
        ex['performed_at'],
        ex['entry_date'],
        ex['last_performed_at'],
      ];
      for (final c in candidates) {
        final dt = _parseDate(c);
        if (dt != null) return dt;
      }
      return null;
    }

    bool _isCurrentWeekDate(DateTime? dt) {
      if (dt == null) return false;
      return TrainingResetCoordinator.isInWeek(
        dt,
        weekStart: _weekStart,
        weekEnd: _weekEnd,
      );
    }

    final completionDate = _completionDateForExercise(exercise);

    bool _isInCurrentWeek(dynamic loggedAt) {
      final dt = _parseDate(loggedAt);
      if (dt == null) return false;
      return TrainingResetCoordinator.isInWeek(
        dt,
        weekStart: _weekStart,
        weekEnd: _weekEnd,
      );
    }

    bool _isCompleted(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final s = value.toString().trim().toLowerCase();
      if (s.isEmpty) return false;
      // Accept common truthy markers, including "1", "t", and numeric strings.
      if (s == "true" || s == "yes" || s == "y" || s == "t" || s == "1") {
        return true;
      }
      final numeric = num.tryParse(s);
      if (numeric != null) return numeric != 0;
      // Fallback: any non-falsey string is treated as completed (e.g. logged_at timestamp).
      return !(s == "false" || s == "f" || s == "no" || s == "n" || s == "0");
    }

    bool _hasComplianceCompleted(dynamic compliance) {
      if (compliance == null) return false;
      if (compliance is String) {
        try {
          final decoded = jsonDecode(compliance);
          return _hasComplianceCompleted(decoded);
        } catch (_) {
          return _isCompleted(compliance);
        }
      }
      if (compliance is Map) {
        final complianceDate =
            _parseDate(
              compliance['logged_at'] ??
                  compliance['completed_at'] ??
                  compliance['performed_at'] ??
                  compliance['entry_date'],
            );
        if (complianceDate == null || !_isInCurrentWeek(complianceDate)) {
          return false;
        }
        // Check common fields returned from program_compliance payloads. Ignore logged_at alone;
        // we only consider explicit completion flags or logged performance metrics.
        final possibleFlags = [
          compliance['completed'],
          compliance['is_completed'],
          compliance['performed_sets'],
          compliance['performed_reps'],
          compliance['performed_time_seconds'],
          // Consider textual statuses that imply completion.
          if (compliance['status'] != null)
            (compliance['status'].toString().toLowerCase().contains(
                  "complete",
                ) ||
                compliance['status'].toString().toLowerCase().contains(
                  "done",
                ) ||
                compliance['status'].toString().toLowerCase().contains(
                  "finish",
                )),
        ];
        return possibleFlags.any(_isCompleted);
      }
      if (compliance is Iterable) {
        return compliance.any((item) => _hasComplianceCompleted(item));
      }
      return _isCompleted(compliance);
    }

    final complianceDone =
        _hasComplianceCompleted(exercise['program_compliance']) ||
        _hasComplianceCompleted(exercise['compliance']);
    final hasCurrentWeekDate = _isCurrentWeekDate(completionDate);

    final String? overrideSets = (complianceDone || hasCurrentWeekDate)
        ? _valueAsText(
            compliance?['performed_sets'] ?? exercise['performed_sets'],
          )
        : null;
    final String? overrideReps = (complianceDone || hasCurrentWeekDate)
        ? _valueAsText(
            compliance?['performed_reps'] ?? exercise['performed_reps'],
          )
        : null;
    final String setsLabel = overrideSets ?? exercise['sets'].toString();
    final String repsLabel = overrideReps ?? exercise['reps'].toString();
    final String? overrideRir = (complianceDone || hasCurrentWeekDate)
        ? _valueAsText(
            compliance?['performed_rir'] ?? exercise['performed_rir'],
          )
        : null;
    final String rirLabel = overrideRir ?? exercise['rir'].toString();

    // Accept multiple backend representations for completion/compliance flags.
    final completionFields = [
      exercise['is_completed'],
      exercise['completed'],
      exercise['program_compliance_completed'],
      exercise['compliance_status'],
      exercise['performed_sets'],
      exercise['performed_reps'],
      exercise['performed_time_seconds'],
      exercise['weight_used'],
    ];

    final bool completed =
        forceCompleted ||
        complianceDone ||
        (hasCurrentWeekDate && completionFields.any(_isCompleted));
    final bool showProgress = inProgress;
    final cs = Theme.of(context).colorScheme;

    final gradientColors = showProgress
        ? const [Color(0xFF251A0B), Color(0xFF120D08)]
        : completed
        ? const [Color(0xFF0E2A1E), Color(0xFF0B1F1A)]
        : const [Color(0xFF0F162A), Color(0xFF0A0F1C)];
    final shadowColor = showProgress
        ? const Color(0xFFFFB347).withOpacity(0.35)
        : completed
        ? Colors.greenAccent.withOpacity(0.35)
        : Colors.black.withOpacity(0.45);
    final borderColor = showProgress
        ? const Color(0xFFFFC870).withOpacity(0.75)
        : completed
        ? Colors.greenAccent.withOpacity(0.6)
        : Colors.white.withOpacity(0.07);
    final statusChip = completed && !showProgress
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 14, color: Colors.greenAccent),
                SizedBox(width: 3),
                Text(
                  "Done",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.greenAccent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        : null;
    final progressChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB347).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD68A)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timelapse_rounded, size: 14, color: Color(0xFFFFD68A)),
          SizedBox(width: 4),
          Text(
            "Progress",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFE6B0),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
    final replaceChip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onReplace,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(disabled ? 0.03 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white24.withOpacity(disabled ? 0.5 : 1),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
            SizedBox(width: 4),
            Text(
              "Replace",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: AbsorbPointer(
        absorbing: disabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: disabled ? null : onTap,
            child: Stack(
              children: [
                Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: completed ? 18 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 74,
                            height: 66,
                            color: Colors.black26,
                            child: () {
                              final dpr = MediaQuery.of(
                                context,
                              ).devicePixelRatio;
                              final cacheW = (74 * dpr).round();
                              final cacheH = (66 * dpr).round();
                              final url = TrainingService.animationImageUrl(
                                exercise['animation_url']?.toString(),
                                null,
                              );
                              if (url.isEmpty) {
                                return const Icon(
                                  Icons.fitness_center,
                                  size: 20,
                                  color: Colors.white24,
                                );
                              }
                              return _ExerciseGifThumb(
                                key: ValueKey(url),
                                url: url,
                                cacheWidth: cacheW,
                                cacheHeight: cacheH,
                              );
                            }(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      exercise['exercise_name'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: showProgress
                                            ? const Color(0xFFFFD68A)
                                            : completed
                                            ? Colors.greenAccent
                                            : Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (statusChip != null) statusChip,
                                  const SizedBox(width: 6),
                                  if (!isCardio && showProgress) progressChip,
                                  if (!completed && !isCardio && !showProgress)
                                    replaceChip,
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (!isCardio)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _StatChip(
                                      icon: Icons.repeat,
                                      label: "$setsLabel x $repsLabel",
                                    ),
                                    _StatChip(
                                      icon: Icons.bolt,
                                      label: "RIR $rirLabel",
                                    ),
                                  ],
                                ),
                              if ((exercise['primary_muscles'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.fiber_manual_record,
                                      size: 10,
                                      color: cs.secondary.withOpacity(0.85),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        exercise['primary_muscles'],
                                        style: TextStyle(
                                          color: cs.secondary.withOpacity(0.85),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            SizedBox(height: 1),
                            Text(
                              "start",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (showProgress)
                  const Positioned.fill(
                    child: IgnorePointer(child: _SnakeEdgeGlow()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SnakeEdgeGlow extends StatefulWidget {
  const _SnakeEdgeGlow();

  @override
  State<_SnakeEdgeGlow> createState() => _SnakeEdgeGlowState();
}

class _SnakeEdgeGlowState extends State<_SnakeEdgeGlow>
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
        builder: (_, __) => CustomPaint(
          painter: _SnakeEdgeGlowPainter(progress: _controller.value),
        ),
      ),
    );
  }
}

class _SnakeEdgeGlowPainter extends CustomPainter {
  final double progress;

  const _SnakeEdgeGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      const Radius.circular(16),
    );
    final inner = outer.deflate(2.4);

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
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5);
    canvas.drawRRect(outer.deflate(0.8), glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SnakeEdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ExerciseGifThumb extends StatefulWidget {
  const _ExerciseGifThumb({
    super.key,
    required this.url,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final String url;
  final int cacheWidth;
  final int cacheHeight;

  @override
  State<_ExerciseGifThumb> createState() => _ExerciseGifThumbState();
}

class _ExerciseGifThumbState extends State<_ExerciseGifThumb> {
  bool _hasFrame = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  ImageProvider get _provider => TrainingService.gifProvider(
    widget.url,
    cacheWidth: widget.cacheWidth,
    cacheHeight: widget.cacheHeight,
  );

  void _attachStream() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      TrainingService.cacheGifFrame(
        widget.url,
        info,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
      );
      if (!_hasFrame && mounted) {
        setState(() => _hasFrame = true);
      }
    });
    stream.addListener(_listener!);
  }

  void _detachStream() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detachStream();
    _attachStream();
  }

  @override
  void didUpdateWidget(covariant _ExerciseGifThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _hasFrame = false;
      _detachStream();
      _attachStream();
    }
  }

  @override
  void dispose() {
    _detachStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cached = TrainingService.getGifFrame(
      widget.url,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (cached != null)
          RawImage(image: cached.image, scale: cached.scale, fit: BoxFit.cover)
        else
          const Icon(Icons.fitness_center, size: 20, color: Colors.white24),
        Image(
          image: _provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _StatChip({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (accent ?? Colors.white).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (accent ?? Colors.white).withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent ?? Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
