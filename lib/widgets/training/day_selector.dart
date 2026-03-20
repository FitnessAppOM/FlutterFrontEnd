import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<bool> completed;
  final List<bool> disabled;
  final List<String?> notes;

  const DaySelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.completed = const [],
    this.disabled = const [],
    this.notes = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const completedGradient = LinearGradient(
      colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
    );
    final hasNotes = notes.any((n) => n != null && n.trim().isNotEmpty);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SizedBox(
        height: hasNotes ? 58 : 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final selected = i == selectedIndex;
            final isCompleted = i < completed.length ? completed[i] : false;
            final isDisabled = i < disabled.length ? disabled[i] : false;
            final note = i < notes.length ? notes[i] : null;
            return GestureDetector(
              onTap: isDisabled ? null : () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: (selected && !isDisabled)
                      ? (isCompleted
                          ? completedGradient
                          : const LinearGradient(
                              colors: [Color(0xFF2D8CFF), Color(0xFF5E5CFF)],
                            ))
                      : null,
                  color: isDisabled
                      ? Colors.white.withOpacity(0.05)
                      : (selected
                          ? null
                          : (isCompleted
                              ? const Color(0xFF2ECC71).withOpacity(0.18)
                              : Colors.white.withOpacity(0.08))),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDisabled
                        ? Colors.white.withOpacity(0.18)
                        : (isCompleted
                            ? const Color(0xFF2ECC71)
                                .withOpacity(selected ? 0.9 : 0.6)
                            : Colors.white.withOpacity(0.18)),
                  ),
                  boxShadow: selected
                      ? (isDisabled
                          ? null
                          : [
                          BoxShadow(
                            color: (isCompleted
                                    ? const Color(0xFF2ECC71)
                                    : cs.primary)
                                .withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ])
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: isDisabled
                            ? Colors.white54
                            : (selected
                                ? Colors.white
                                : (isCompleted
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.8))),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (note != null && note.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
