import 'package:flutter/material.dart';

import '../../services/daily_outlook/daily_outlook_service.dart';
import '../../theme/app_theme.dart';
import '../Main/card_container.dart';

class DailyOutlookCard extends StatelessWidget {
  const DailyOutlookCard({
    super.key,
    required this.loading,
    required this.generating,
    required this.status,
    required this.onGenerate,
    required this.title,
    required this.subtitle,
    required this.generateLabel,
    required this.generatedLabel,
    required this.onceDailyLabel,
  });

  final bool loading;
  final bool generating;
  final DailyOutlookStatus? status;
  final VoidCallback? onGenerate;
  final String title;
  final String subtitle;
  final String generateLabel;
  final String generatedLabel;
  final String onceDailyLabel;

  @override
  Widget build(BuildContext context) {
    final outlook = status?.outlook;
    final generated = status?.generated == true && outlook != null;

    return CardContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_outlined,
                    color: Color(0xFFFFC857),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        generated ? generatedLabel : subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading || generating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (generated) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ReadinessPill(label: outlook.readinessState),
                  Text(
                    onceDailyLabel,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                outlook.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                outlook.summary,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (outlook.actionItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...outlook.actionItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFFFFC857),
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (outlook.cautionNote.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    outlook.cautionNote,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ] else ...[
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (loading || generating) ? null : onGenerate,
                  child: Text(generating ? "$generateLabel..." : generateLabel),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                onceDailyLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadinessPill extends StatelessWidget {
  const _ReadinessPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.$1.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (Color, Color) _colorsFor(String raw) {
    final value = raw.toLowerCase().trim();
    if (value.contains('hard')) {
      return (const Color(0xFF2ED573), const Color(0xFF90FFBC));
    }
    if (value.contains('light')) {
      return (const Color(0xFFFFC857), const Color(0xFFFFE4A3));
    }
    return (const Color(0xFFFF6B6B), const Color(0xFFFFC1C1));
  }
}
