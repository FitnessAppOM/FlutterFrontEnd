import 'package:flutter/material.dart';

import '../../services/scores/taqa_score_api.dart';

class TaqaScoreWidget extends StatefulWidget {
  const TaqaScoreWidget({
    super.key,
    required this.score,
    required this.loading,
    required this.onTap,
    this.provider,
    this.scoreDayLabel,
    this.emptyMessage = "No score data yet",
  });

  final TaqaDailyScore? score;
  final bool loading;
  final VoidCallback onTap;
  final String? provider;
  final String? scoreDayLabel;
  final String emptyMessage;

  @override
  State<TaqaScoreWidget> createState() => _TaqaScoreWidgetState();
}

class _TaqaScoreWidgetState extends State<TaqaScoreWidget>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taqaValue = widget.score?.taqaValueScore;
    final display = taqaValue == null ? "--" : taqaValue.round().toString();
    final progress = taqaValue == null
        ? 0.0
        : (taqaValue / 100).clamp(0.0, 1.0);

    final Color ringColor;
    if (taqaValue == null) {
      ringColor = Colors.white24;
    } else if (taqaValue >= 75) {
      ringColor = const Color(0xFF4CD964);
    } else if (taqaValue >= 50) {
      ringColor = const Color(0xFFFFD700);
    } else if (taqaValue >= 25) {
      ringColor = const Color(0xFFFF8A00);
    } else {
      ringColor = const Color(0xFFFF6B6B);
    }

    final miniScores = _buildMiniScores();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6A5AE0).withValues(alpha: 0.15),
                const Color(0xFF6A5AE0).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
            ),
          ),
          child: widget.loading
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF6A5AE0),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: taqaValue == null ? 1.0 : _pulseAnim.value,
                          child: child,
                        );
                      },
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 84,
                              height: 84,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 7,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation(ringColor),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              display,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bolt,
                                color: Color(0xFF6A5AE0),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "TAQA Score",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white.withValues(alpha: 0.4),
                                size: 20,
                              ),
                            ],
                          ),
                          if (widget.scoreDayLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.scoreDayLabel!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (widget.provider != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.provider == 'fitbit'
                                  ? 'Fitbit'
                                  : widget.provider == 'whoop'
                                  ? 'WHOOP'
                                  : widget.provider!,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (miniScores.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: miniScores,
                            )
                          else
                            Text(
                              taqaValue == null
                                  ? widget.emptyMessage
                                  : "Tap to see details",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _buildMiniScores() {
    final s = widget.score;
    if (s == null) return const [];

    final items = <_MiniItem>[];
    if (s.sleep.score != null) {
      items.add(_MiniItem("Sleep", s.sleep.score!, const Color(0xFF9B8CFF)));
    }
    if (s.recovery.score != null) {
      items.add(
        _MiniItem("Recovery", s.recovery.score!, const Color(0xFF4CD964)),
      );
    }
    if (s.stress.score != null) {
      items.add(
        _MiniItem(
          "Stress",
          s.stress.score!,
          const Color(0xFFFF6B6B),
          inverted: true,
        ),
      );
    }
    if (s.trainingLoad.score != null) {
      items.add(
        _MiniItem("Load", s.trainingLoad.score!, const Color(0xFFFF8A00)),
      );
    }
    if (s.nutrition.score != null) {
      items.add(
        _MiniItem("Nutrition", s.nutrition.score!, const Color(0xFF00BFA6)),
      );
    }

    return items
        .take(4)
        .map(
          (item) => _MiniScorePill(
            label: item.label,
            value: item.value,
            color: item.color,
            inverted: item.inverted,
          ),
        )
        .toList();
  }
}

class _MiniItem {
  final String label;
  final double value;
  final Color color;
  final bool inverted;
  const _MiniItem(this.label, this.value, this.color, {this.inverted = false});
}

class _MiniScorePill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool inverted;

  const _MiniScorePill({
    required this.label,
    required this.value,
    required this.color,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final effective = inverted ? (100 - value) : value;
    final Color dotColor;
    if (effective >= 75) {
      dotColor = const Color(0xFF4CD964);
    } else if (effective >= 50) {
      dotColor = const Color(0xFFFFD700);
    } else {
      dotColor = const Color(0xFFFF6B6B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            "${value.round()}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
