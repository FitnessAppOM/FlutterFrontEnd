import 'package:flutter/material.dart';
import '../Main/card_container.dart';

class ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool completed = exercise['is_completed'] == true;
    final String? animPath = exercise['animation_rel_path'];

    Widget leading = const Icon(
      Icons.fitness_center,
      size: 32,
      color: Colors.grey,
    );

    if (animPath != null && animPath.isNotEmpty) {
      leading = SizedBox(
        width: 56,
        height: 56,
        child: Image.asset(
          'assets/$animPath',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.fitness_center,
              size: 32,
              color: Colors.grey,
            );
          },
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: CardContainer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise['exercise_name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${exercise['sets']} x ${exercise['reps']} • RIR ${exercise['rir']}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            completed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.play_arrow),
          ],
        ),
      ),
    );
  }
}
