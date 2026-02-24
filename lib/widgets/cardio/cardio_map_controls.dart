import 'dart:async';
import 'package:flutter/material.dart';
import '../common/gradient_bubble_button.dart';

class CardioMapControls extends StatefulWidget {
  const CardioMapControls({
    super.key,
    this.onStart,
    this.onPause,
    this.onFinish,
    this.distanceKm,
    this.speedKmh,
    this.steps,
    this.elapsedSeconds,
    this.running,
  });

  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onFinish;
  final double? distanceKm;
  final double? speedKmh;
  final int? steps;
  final int? elapsedSeconds;
  final bool? running;

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

  @override
  void didUpdateWidget(covariant CardioMapControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.elapsedSeconds != null) {
      final next = Duration(
        seconds: widget.elapsedSeconds!.clamp(0, 1 << 31),
      );
      if (next != _elapsed) {
        _elapsed = next;
      }
      _timer?.cancel();
    }
    if (widget.running != null) {
      _running = widget.running!;
      _showStats = _running || _showStats;
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
      setState(() {
        _showStats = true;
        _countdown = 3;
      });
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
    if (_countdown != null) return;
    _timer?.cancel();
    setState(() {
      _running = false;
      _showStats = false;
      _elapsed = Duration.zero;
    });
    widget.onFinish?.call();
  }

  String get _time =>
      "${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}";

  String _paceLabel(double? speedKmh) {
    if (_elapsed.inSeconds < 30) return "--:-- /km";
    if (speedKmh == null || speedKmh <= 0.1) return "--:-- /km";
    final paceMin = 60.0 / speedKmh;
    final paceMinutes = paceMin.floor();
    final paceSeconds = ((paceMin - paceMinutes) * 60).round().clamp(0, 59);
    return "${paceMinutes.toString().padLeft(2, '0')}:${paceSeconds.toString().padLeft(2, '0')} /km";
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = (widget.distanceKm ?? 0).toStringAsFixed(2);
    final paceLabel = _paceLabel(widget.speedKmh);
    final stepsLabel = widget.steps?.toString() ?? "0";
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          offset: _showStats ? Offset.zero : const Offset(0, 0.25),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showStats ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F1A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _StatPill(label: "Time", value: _time),
                  const SizedBox(width: 8),
                  _StatPill(label: "Distance", value: "$distanceLabel km"),
                  const SizedBox(width: 8),
                  _StatPill(label: "Pace", value: paceLabel),
                  const SizedBox(width: 8),
                  _StatPill(label: "Steps", value: stepsLabel),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 64,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!_running && _countdown == null)
                (_showStats
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GradientBubbleButton(
                            icon: Icons.play_arrow_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0x33FFFFFF), Color(0x55D1E9FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: _handleStart,
                          ),
                          const SizedBox(width: 12),
                          GradientBubbleButton(
                            icon: Icons.check_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0x33FFFFFF), Color(0x55D1E9FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: _handleFinish,
                          ),
                        ],
                      )
                    : GradientBubbleButton(
                        icon: Icons.play_arrow_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0x33FFFFFF), Color(0x55D1E9FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: _handleStart,
                      ))
              else if (_countdown != null)
                GradientBubbleButton(
                  child: Text(
                    _countdown.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  gradient: const LinearGradient(
                    colors: [Color(0x33FFFFFF), Color(0x55D1E9FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: null,
                )
              else
                const SizedBox.shrink(),
              if (_running)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GradientBubbleButton(
                      icon: Icons.pause_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0x33FFFFFF), Color(0x55D1E9FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: _handlePause,
                    ),
                    const SizedBox(width: 12),
                    GradientBubbleButton(
                      icon: Icons.check_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0x33FFFFFF), Color(0x55D1E9FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
