import 'dart:async';
import 'package:flutter/material.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';

class CardioMapControls extends StatefulWidget {
  const CardioMapControls({
    super.key,
    this.onStart,
    this.onCountdownStart,
    this.onPause,
    this.onFinish,
    this.distanceKm,
    this.speedKmh,
    this.steps,
    this.elapsedSeconds,
    this.running,
    this.showStatBar = true,
    this.alwaysShowStatBar = false,
    this.showTimePill = true,
    this.showDistancePill = true,
    this.showPacePill = true,
    this.showStepsPill = true,
  });

  final VoidCallback? onStart;
  final VoidCallback? onCountdownStart;
  final VoidCallback? onPause;
  final VoidCallback? onFinish;
  final double? distanceKm;
  final double? speedKmh;
  final int? steps;
  final int? elapsedSeconds;
  final bool? running;
  final bool showStatBar;
  final bool alwaysShowStatBar;
  final bool showTimePill;
  final bool showDistancePill;
  final bool showPacePill;
  final bool showStepsPill;

  @override
  State<CardioMapControls> createState() => _CardioMapControlsState();
}

class _CardioMapControlsState extends State<CardioMapControls> {
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Timer? _countdownTimer;
  bool _running = false;
  bool _showStats = false;
  int? _countdown;
  bool _finishing = false;

  @override
  void didUpdateWidget(covariant CardioMapControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.elapsedSeconds != null) {
      final next = Duration(seconds: widget.elapsedSeconds!.clamp(0, 1 << 31));
      if (next != _elapsed) {
        _elapsed = next;
      }
      _timer?.cancel();
    }
    if (widget.running != null) {
      _running = widget.running!;
      final hasElapsed = (widget.elapsedSeconds ?? 0) > 0;
      _showStats = _running || hasElapsed || _showStats;
      if (_running) {
        _countdown = null;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _handleStart() {
    if (_countdown != null) return;
    if (!_running) {
      if (_showStats) {
        setState(() {
          _countdown = null;
          _running = true;
        });
        if (widget.elapsedSeconds == null) {
          _startTimer();
        }
        widget.onStart?.call();
        return;
      }
      setState(() {
        _showStats = true;
        _countdown = 3;
      });
      widget.onCountdownStart?.call();
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        final next = (_countdown ?? 1) - 1;
        if (next <= 0) {
          t.cancel();
          setState(() {
            _countdown = null;
            _running = true;
          });
          if (widget.elapsedSeconds == null) {
            _startTimer();
          }
          widget.onStart?.call();
          return;
        }
        setState(() => _countdown = next);
      });
      return;
    }
  }

  void _handlePause() {
    if (_countdown != null) return;
    setState(() => _running = false);
    widget.onPause?.call();
  }

  void _handleFinish() {
    if (_countdown != null || _finishing) return;
    setState(() {
      _finishing = true;
      _running = false;
    });
    widget.onFinish?.call();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _finishing = false;
    });
  }

  String get _time =>
      "${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}";

  String _paceLabel() {
    if (_elapsed.inSeconds < 30) return "--:-- /km";
    final distanceKm = widget.distanceKm ?? 0.0;
    if (distanceKm <= 0.001) return "--:-- /km";
    final paceMin = (_elapsed.inSeconds / 60.0) / distanceKm;
    final paceMinutes = paceMin.floor();
    final paceSeconds = ((paceMin - paceMinutes) * 60).round().clamp(0, 59);
    return "${paceMinutes.toString().padLeft(2, '0')}:${paceSeconds.toString().padLeft(2, '0')} /km";
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = (widget.distanceKm ?? 0).toStringAsFixed(2);
    final paceLabel = _paceLabel();
    final stepsLabel = widget.steps?.toString() ?? "0";
    final statPills = <Widget>[
      if (widget.showTimePill) _MetricReadout(label: "Time", value: _time),
      if (widget.showDistancePill)
        _MetricReadout(label: "Distance", value: "$distanceLabel km"),
      if (widget.showPacePill) _MetricReadout(label: "Pace", value: paceLabel),
      if (widget.showStepsPill)
        _MetricReadout(label: "Steps", value: stepsLabel),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showStatBar)
          AnimatedSlide(
            offset: (widget.alwaysShowStatBar || _showStats)
                ? Offset.zero
                : const Offset(0, 0.25),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: (widget.alwaysShowStatBar || _showStats) ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Container(
                padding: TaqaUiScale.insetsLTRB(14, 10, 14, 10),
                margin: EdgeInsets.only(bottom: TaqaUiScale.h(18)),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D20),
                  borderRadius: TaqaUiScale.radius(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < statPills.length; i++) ...[
                      statPills[i],
                      if (i != statPills.length - 1)
                        SizedBox(width: TaqaUiScale.w(8)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          height: TaqaUiScale.h(64),
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!_running && _countdown == null)
                (_showStats
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CardioActionButton(
                            icon: Icons.play_arrow_rounded,
                            style: _CardioActionStyle.primary,
                            onTap: _handleStart,
                          ),
                          SizedBox(width: TaqaUiScale.w(12)),
                          _CardioActionButton(
                            icon: Icons.check_rounded,
                            style: _CardioActionStyle.primary,
                            onTap: _handleFinish,
                          ),
                        ],
                      )
                    : _CardioActionButton(
                        icon: Icons.play_arrow_rounded,
                        style: _CardioActionStyle.primary,
                        onTap: _handleStart,
                      ))
              else if (_countdown != null)
                _CardioActionButton(
                  style: _CardioActionStyle.primary,
                  onTap: null,
                  child: Text(
                    _countdown.toString(),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      fontSize: TaqaUiScale.sp(22),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (_running)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardioActionButton(
                      icon: Icons.pause_rounded,
                      style: _CardioActionStyle.secondary,
                      onTap: _handlePause,
                    ),
                    SizedBox(width: TaqaUiScale.w(12)),
                    _CardioActionButton(
                      icon: Icons.check_rounded,
                      style: _CardioActionStyle.primary,
                      onTap: _handleFinish,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _CardioActionStyle { primary, secondary }

/// Circular action button matching the indoor-cardio session dock's lime
/// accent language, used here for the outdoor/map cardio controls so both
/// flows read as one design system instead of the old translucent gradient
/// bubble buttons.
class _CardioActionButton extends StatelessWidget {
  const _CardioActionButton({
    this.icon,
    this.child,
    required this.style,
    required this.onTap,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final _CardioActionStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPrimary = style == _CardioActionStyle.primary;
    final size = TaqaUiScale.w(56);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: TaqaUiScale.radius(999),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // The old translucent-white fill was nearly invisible against a
            // busy map background, reading as a broken/ghost circle. Give
            // the secondary (pause) button a solid dark fill so it's as
            // legible as the lime primary button.
            color: isPrimary ? TaqaUiColors.lime : const Color(0xFF1D1D20),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.18),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child:
              child ??
              Icon(
                icon,
                color: isPrimary ? TaqaUiColors.unnamedColor1c1d17 : Colors.white,
                size: TaqaUiScale.sp(24),
              ),
        ),
      ),
    );
  }
}

class _MetricReadout extends StatelessWidget {
  const _MetricReadout({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: TaqaUiScale.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: TaqaUiScale.radius(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(4)),
            Text(
              value,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: TaqaUiScale.sp(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
