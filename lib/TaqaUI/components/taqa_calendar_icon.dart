import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reuses TAQA's food/training artwork and distinct activity symbols.
class TaqaCalendarIcon extends StatelessWidget {
  const TaqaCalendarIcon({
    super.key,
    required this.kind,
    this.activityKind,
    this.color,
    this.size = 20,
  });

  final String kind;
  final String? activityKind;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? IconTheme.of(context).color ?? Colors.black;
    final asset = switch (kind) {
      'food' => 'assets/icons/Diet.svg',
      'training' => 'assets/icons/Exercise.svg',
      'activity' when activityKind == 'weightlifting' =>
        'assets/icons/Exercise.svg',
      _ => null,
    };
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
      );
    }
    final icon = kind == 'sleep'
        ? Icons.bedtime_rounded
        : switch (activityKind) {
            'run' => Icons.directions_run_rounded,
            'cycle' => Icons.directions_bike_rounded,
            'swim' => Icons.pool_rounded,
            'hike' => Icons.hiking_rounded,
            'yoga' => Icons.self_improvement_rounded,
            'other' => Icons.sports_rounded,
            _ => Icons.directions_walk_rounded,
          };
    return Icon(icon, size: size, color: foreground);
  }
}
