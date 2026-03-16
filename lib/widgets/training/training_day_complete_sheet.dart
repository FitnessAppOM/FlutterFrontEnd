import 'package:flutter/material.dart';

class TrainingDayCompleteSheet extends StatelessWidget {
  const TrainingDayCompleteSheet({
    super.key,
    required this.dayLabel,
  });

  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F162A),
                Color(0xFF1B2D4A),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -12,
                bottom: -18,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 34,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Day complete",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$dayLabel finished. Great work!",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Nice!",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
