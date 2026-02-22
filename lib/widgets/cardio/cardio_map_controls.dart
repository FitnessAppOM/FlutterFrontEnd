import 'dart:async';
import 'package:flutter/material.dart';

class CardioMapControls extends StatefulWidget {
  const CardioMapControls({
    super.key,
    this.onStart,
    this.onPause,
    this.onFinish,
    this.distanceKm,
    this.speedKmh,
  });

  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onFinish;
  final double? distanceKm;
  final double? speedKmh;

  @override
  State<CardioMapControls> createState() => _CardioMapControlsState();
}

class _CardioMapControlsState extends State<CardioMapControls> {
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _running = false;
  bool _showStats = false;

  @override
  void dispose() {
    _timer?.cancel();
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
    if (!_running) {
      setState(() {
        _running = true;
        _showStats = true;
      });
      _startTimer();
    }
    widget.onStart?.call();
  }

  void _handlePause() {
    setState(() => _running = false);
    widget.onPause?.call();
  }

  void _handleFinish() {
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

  @override
  Widget build(BuildContext context) {
    final distanceLabel = (widget.distanceKm ?? 0).toStringAsFixed(2);
    final speedLabel = (widget.speedKmh ?? 0).toStringAsFixed(1);
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
                  _StatPill(label: "Speed", value: "$speedLabel km/h"),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F1A).withOpacity(0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _ActionPill(
                label: _running ? "Running" : "Start",
                icon: _running ? Icons.play_arrow_rounded : Icons.play_arrow_rounded,
                filled: true,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8CFF6A), Color(0xFF4CF08A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: _handleStart,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                label: _running ? "Pause" : "Paused",
                icon: Icons.pause_rounded,
                filled: true,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8B6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: _handlePause,
              ),
              const SizedBox(width: 10),
              _ActionPill(
                label: "Finish",
                icon: Icons.check_rounded,
                onTap: _handleFinish,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? gradient : null;
    final border = filled
        ? Colors.transparent
        : Colors.white.withOpacity(0.18);
    final fg = filled ? Colors.black : Colors.white;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: bg,
              color: filled ? null : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
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
