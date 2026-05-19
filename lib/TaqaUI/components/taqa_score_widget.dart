import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/scores/taqa_score_api.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaScoreWidget extends StatelessWidget {
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
  final VoidCallback? onTap;
  final String? provider;
  final String? scoreDayLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final localizedTitle = AppLocalizations.of(
      context,
    ).translate('taqa_label_taqa_value');
    final taqaTitle = localizedTitle == 'TAQA Fitness Score'
        ? 'Taqa Fitness Score'
        : localizedTitle;
    final taqaValue = score?.taqaValueScore ?? 0;
    final displayValue = taqaValue.round();
    final progress = (taqaValue / 100).clamp(0.0, 1.0);
    final dateLabel = (scoreDayLabel == null || scoreDayLabel!.trim().isEmpty)
        ? '--.--'
        : scoreDayLabel!.replaceAll('/', '.');
    final displayProvider = score?.scoringPath == 'wearable'
        ? (provider ?? score?.provider)
        : null;
    final providerLabel = displayProvider == null
        ? emptyMessage
        : _providerLabel(displayProvider);
    final dataChips = _buildDataChips(score);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.cardRadius,
        child: Container(
          decoration: const BoxDecoration(
            color: TaqaUiColors.lime,
            borderRadius: TaqaUiStyles.cardRadius,
          ),
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 16),
          child: loading
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size.square(150),
                            painter: _OpenArcPainter(progress: progress),
                          ),
                          Text(
                            '$displayValue',
                            style: const TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: TaqaUiColors.charcoal,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            taqaTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: TaqaUiColors.charcoal,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              color: TaqaUiColors.charcoal,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            providerLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              color: TaqaUiColors.charcoal,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (dataChips.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: dataChips
                                  .map((item) => _ScoreChip(item: item))
                                  .toList(),
                            )
                          else
                            Text(
                              emptyMessage,
                              style: const TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: 8,
                                fontWeight: FontWeight.w400,
                                color: TaqaUiColors.charcoal,
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

  String _providerLabel(String providerValue) {
    switch (providerValue) {
      case 'fitbit':
        return 'Fitbit';
      case 'whoop':
        return 'WHOOP';
      case 'google_fit':
        return 'Google Fit';
      case 'samsung':
        return 'Samsung Health';
      case 'healthkit':
        return 'Apple / Google';
      default:
        return providerValue;
    }
  }

  List<_ScoreChipData> _buildDataChips(TaqaDailyScore? value) {
    if (value == null) return const [];
    final out = <_ScoreChipData>[];

    void addIf(String label, double? score) {
      if (score == null) return;
      out.add(_ScoreChipData(label: label, value: score.round()));
    }

    addIf('Sleep', value.sleep.score);
    addIf('Recovery', value.recovery.score);
    addIf('Stress', value.stress.score);
    addIf('Load', value.trainingLoad.score);
    addIf('Nutrition', value.nutrition.score);
    return out;
  }
}

class _OpenArcPainter extends CustomPainter {
  const _OpenArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = TaqaUiColors.charcoal.withValues(alpha: 0.14);

    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = TaqaUiColors.charcoal.withValues(alpha: 0.3);

    const start = 3 * math.pi / 4; // 135deg (bottom-left)
    const sweep = 3 * math.pi / 2; // 270deg (open gap at bottom)

    canvas.drawArc(rect, start, sweep, false, base);
    if (progress > 0) {
      canvas.drawArc(rect, start, sweep * progress, false, value);
    }
  }

  @override
  bool shouldRepaint(covariant _OpenArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ScoreChipData {
  const _ScoreChipData({required this.label, required this.value});

  final String label;
  final int value;
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.item});

  final _ScoreChipData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TaqaUiColors.charcoal, width: 1),
      ),
      child: Text(
        '${item.value} ${item.label}',
        style: const TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: 8,
          fontWeight: FontWeight.w400,
          color: TaqaUiColors.charcoal,
          height: 1.1,
        ),
      ),
    );
  }
}
