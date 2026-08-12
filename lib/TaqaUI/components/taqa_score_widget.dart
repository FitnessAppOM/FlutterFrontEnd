import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../Typography/taqa_ui_typography.dart';

import '../../localization/app_localizations.dart';
import '../../services/scores/taqa_score_api.dart';
import '../taqa_ui_colors.dart';
import 'taqa_score_card.dart';

class TaqaScoreWidget extends StatelessWidget {
  const TaqaScoreWidget({
    super.key,
    required this.score,
    required this.loading,
    required this.onTap,
    this.provider,
    this.scoreDayLabel,
    this.emptyMessage,
  });

  final TaqaDailyScore? score;
  final bool loading;
  final VoidCallback? onTap;
  final String? provider;
  final String? scoreDayLabel;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    String t(String key) => localizations.translate(key);
    final taqaTitle = t('taqa_label_taqa_value');
    final taqaValue = score?.taqaValueScore ?? 0;
    final displayValue = taqaValue.round();
    final progress = (taqaValue / 100).clamp(0.0, 1.0);
    final dateLabel = (scoreDayLabel == null || scoreDayLabel!.trim().isEmpty)
        ? '--.--'
        : scoreDayLabel!.replaceAll('/', '.');
    final displayProvider = score?.scoringPath == 'wearable'
        ? (provider ?? score?.provider)
        : null;
    final providerLabel = _scoreSourceLabel(score, displayProvider, t);
    final tags = _buildTags(score, displayProvider, t);

    return TaqaScoreCard(
      title: taqaTitle,
      valueText: '$displayValue',
      progress: progress,
      loading: loading,
      metaText: '$dateLabel\n$providerLabel',
      tags: tags,
      emptyMessage: emptyMessage ?? t('taqa_no_data'),
      onTap: onTap,
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

  String _scoreSourceLabel(
    TaqaDailyScore? value,
    String? displayProvider,
    String Function(String) t,
  ) {
    if (displayProvider != null && displayProvider.trim().isNotEmpty) {
      return _providerLabel(displayProvider);
    }
    final scoringPath = value?.scoringPath;
    if (scoringPath == null || scoringPath.trim().isEmpty) return '--';
    switch (scoringPath) {
      case 'wearable':
        return t('taqa_source_smart_watch');
      case 'proms':
        return t('taqa_source_screening');
      case 'journal':
        return t('taqa_source_journal');
      default:
        return _humanizeLabel(scoringPath);
    }
  }

  List<String> _buildTags(
    TaqaDailyScore? value,
    String? displayProvider,
    String Function(String) t,
  ) {
    if (value == null) return const [];
    final out = <String>[];

    final sourceLabel = _chipSourceLabel(value, displayProvider, t);
    if (sourceLabel != null) {
      out.add(sourceLabel);
    }

    void addIf(String label, double? score) {
      if (score == null) return;
      out.add('${score.round()} $label');
    }

    addIf(t('taqa_label_sleep'), value.sleep.score);
    addIf(t('taqa_label_recovery'), value.recovery.score);
    addIf(t('taqa_label_stress'), value.stress.score);
    addIf(t('taqa_tag_load'), value.trainingLoad.score);
    addIf(t('taqa_label_nutrition'), value.nutrition.score);
    return out.take(4).toList(growable: false);
  }

  String? _chipSourceLabel(
    TaqaDailyScore value,
    String? displayProvider,
    String Function(String) t,
  ) {
    if (displayProvider != null && displayProvider.trim().isNotEmpty) {
      return taqaUppercase(_providerLabel(displayProvider));
    }
    final scoringPath = value.scoringPath;
    if (scoringPath == null || scoringPath.trim().isEmpty) return null;
    switch (scoringPath) {
      case 'proms':
        return taqaUppercase(t('taqa_source_screening'));
      case 'wearable':
        return taqaUppercase(t('taqa_source_smart_watch'));
      case 'journal':
        return taqaUppercase(t('taqa_source_journal'));
      default:
        return taqaUppercase(_humanizeLabel(scoringPath));
    }
  }

  String _humanizeLabel(String raw) {
    return raw
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }
}

class TaqaOpenArcPainter extends CustomPainter {
  const TaqaOpenArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.098;
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

    const start = 3 * math.pi / 4;
    const sweep = 3 * math.pi / 2;

    canvas.drawArc(rect, start, sweep, false, base);
    if (progress > 0) {
      canvas.drawArc(rect, start, sweep * progress, false, value);
    }
  }

  @override
  bool shouldRepaint(covariant TaqaOpenArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
