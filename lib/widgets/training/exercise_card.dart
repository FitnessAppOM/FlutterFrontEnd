import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:taqaproject/TaqaUI/Typography/taqa_ui_typography.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';
import '../../services/training/training_service.dart';
import '../../services/training/training_reset_coordinator.dart';

class ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onReplace;
  final VoidCallback? onTap;
  final bool disabled;
  final bool inProgress;
  final bool forceCompleted;
  final bool? completedOverride;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onReplace,
    this.onTap,
    this.disabled = false,
    this.inProgress = false,
    this.forceCompleted = false,
    this.completedOverride,
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

  String _titleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length <= 4 && word == word.toUpperCase()) return word;
          final lower = word.toLowerCase();
          return "${lower[0].toUpperCase()}${lower.substring(1)}";
        })
        .join(' ');
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  double? _positiveWeight(dynamic value) {
    final parsed = _toDouble(value);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  double? _resolvedWeight(Map<String, dynamic> exercise) {
    final rawRows = exercise['set_rows'];
    if (rawRows is List) {
      for (final raw in rawRows) {
        if (raw is! Map) continue;
        final weight = _positiveWeight(raw['weight_kg']);
        if (weight != null) return weight;
      }
    }
    final compliance =
        _extractCompliance(exercise['program_compliance']) ??
        _extractCompliance(exercise['compliance']);
    return _positiveWeight(
          compliance?['weight_used'] ?? exercise['weight_used'],
        ) ??
        _positiveWeight(exercise['weight_kg']);
  }

  String? _formatWeightLabel(double? value) {
    if (value == null) return null;
    final rounded = value.roundToDouble();
    final text = (value - rounded).abs() < 0.001
        ? rounded.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text kg';
  }

  @override
  Widget build(BuildContext context) {
    const previewWidth = 86.0;
    const previewHeight = 78.0;
    const cardPadding = 8.0;

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
        final complianceDate = _parseDate(
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
    final String? weightLabel = _formatWeightLabel(_resolvedWeight(exercise));
    final metaTags = <String>[];
    if (!isCardio) {
      metaTags.add("$setsLabel x $repsLabel");
      metaTags.add("RIR $rirLabel");
      if (weightLabel != null) {
        metaTags.add(weightLabel);
      }
    }

    // Accept multiple backend representations for completion/compliance flags.
    final completionFields = [
      exercise['is_completed'],
      exercise['completed'],
      exercise['history_completed_this_week'],
      exercise['program_compliance_completed'],
      exercise['compliance_status'],
      exercise['performed_sets'],
      exercise['performed_reps'],
      exercise['performed_time_seconds'],
      exercise['weight_used'],
    ];

    final bool completed =
        completedOverride ??
        (forceCompleted ||
            complianceDone ||
            (hasCurrentWeekDate && completionFields.any(_isCompleted)));
    final bool showProgress = inProgress;
    final cs = Theme.of(context).colorScheme;

    final borderColor = showProgress
        ? const Color(0xFFFFD68A)
        : const Color(0x1A1C1D17);
    final showDoneIcon = completed && !showProgress;
    final progressChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x4D1C1D17)),
      ),
      child: const Text(
        "IN PROGRESS",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1D17),
          fontSize: 10,
          letterSpacing: 0.2,
        ),
      ),
    );
    final replaceChip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onReplace,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: const Color(0xFF1C1D17).withOpacity(disabled ? 0.2 : 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz,
              size: 14,
              color: const Color(0xFF1C1D17).withOpacity(disabled ? 0.4 : 1),
            ),
            const SizedBox(width: 4),
            Text(
              "REPLACE",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1D17).withOpacity(disabled ? 0.4 : 1),
                fontSize: 10,
                letterSpacing: 0.2,
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
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                Ink(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: previewHeight + (cardPadding * 2),
                      maxHeight: previewHeight + (cardPadding * 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: previewWidth,
                                  height: previewHeight,
                                  color: const Color(0xFFE3E3E3),
                                  child: () {
                                    final dpr = MediaQuery.of(
                                      context,
                                    ).devicePixelRatio;
                                    final cacheW = (previewWidth * dpr).round();
                                    final cacheH = (previewHeight * dpr)
                                        .round();
                                    final url =
                                        TrainingService.animationImageUrl(
                                          exercise['animation_url']?.toString(),
                                          null,
                                        );
                                    if (url.isEmpty) {
                                      return const Icon(
                                        Icons.fitness_center,
                                        size: 20,
                                        color: Color(0x661C1D17),
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
                                child: SizedBox(
                                  height: previewHeight,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _titleCase(
                                                (exercise['exercise_name'] ??
                                                        '')
                                                    .toString(),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: TaqaUiFontFamilies
                                                    .interTight,
                                                fontWeight: FontWeight.w700,
                                                color: TaqaUiColors
                                                    .unnamedColor1c1d17,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (!isCardio && showProgress)
                                            progressChip,
                                        ],
                                      ),
                                      const Spacer(),
                                      if (!isCardio &&
                                          (exercise['primary_muscles'] ?? '')
                                              .toString()
                                              .isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.fiber_manual_record,
                                              size: 10,
                                              color: cs.secondary.withOpacity(
                                                0.85,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                exercise['primary_muscles'],
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFF1C1D17,
                                                  ).withOpacity(0.85),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (!isCardio && metaTags.isNotEmpty)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    for (
                                                      int i = 0;
                                                      i < metaTags.length;
                                                      i++
                                                    ) ...[
                                                      _MetaTag(
                                                        label: metaTags[i],
                                                      ),
                                                      if (i !=
                                                          metaTags.length - 1)
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (!completed)
                                              const SizedBox(width: 8),
                                            if (!completed) replaceChip,
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (showDoneIcon)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8, right: 2),
                                  child: SizedBox(
                                    height: previewHeight,
                                    child: Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Color(0xFF2ECC71),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x4D1C1D17)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1C1D17),
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 0.2,
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
