import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Main/card_container.dart';

class DietProgressCard extends StatelessWidget {
  const DietProgressCard({
    super.key,
    required this.loading,
    required this.consumedCalories,
    required this.targetCalories,
    this.dayType,
  });

  final bool loading;
  final int? consumedCalories;
  final int? targetCalories;
  final String? dayType;

  @override
  Widget build(BuildContext context) {
    final total = targetCalories ?? 0;
    final consumed = consumedCalories ?? 0;
    final ratio =
        total > 0 ? (consumed / total).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).round();
    final subtitle = total > 0
        ? "$consumed / $total kcal"
        : "No target available";
    final dayLabel = _dayTypeLabel(dayType);

    return CardContainer(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Diet progress",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                else
                  Text(
                    total > 0 ? "$percent%" : "—",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                if (dayLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dayLabel,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: ratio,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _dayTypeLabel(String? raw) {
    if (raw == null) return null;
    final v = raw.toLowerCase().trim();
    if (v == "training") return "Training day";
    if (v == "rest") return "Rest day";
    return null;
  }
}
