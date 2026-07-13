import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Expandable score-pillar card — big number + progress bar + optional
/// source chip, tap to reveal a breakdown of detail rows. This is the exact
/// card used for Sleep/Recovery/Stress/Training Load/Nutrition on the Taqa
/// Fitness Score detail page, extracted so any other score-like metric
/// (e.g. Whoop recovery/strain) can use the identical design.
class TaqaPillarCard extends StatefulWidget {
  final String metricKey;
  final String label;
  final double? score;
  final IconData icon;
  final Color color;
  final String? path;
  final Map<String, dynamic> details;
  final Map<String, String> detailLabels;

  /// Scale [score] is out of, for the progress bar. Defaults to 100 (every
  /// existing Taqa Score pillar is 0-100); pass e.g. 21 for Whoop strain.
  final double maxScore;

  /// Overrides the headline number text (defaults to `score.round()`).
  /// Use this when [score] isn't naturally a whole-number 0-100 value —
  /// e.g. Whoop strain, which is shown with one decimal place. Should be
  /// the number only — pass [unit] separately rather than baking it in,
  /// otherwise FittedBox shrinks the whole string (number + unit) together
  /// and the digits end up smaller than they need to be.
  final String? valueDisplay;

  /// Optional short unit (e.g. "km", "min", "bpm") shown as a small label
  /// in the gap above the headline number, instead of appended inline —
  /// keeps the number itself at full size regardless of unit length.
  final String? unit;

  const TaqaPillarCard({
    super.key,
    required this.metricKey,
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
    this.path,
    required this.details,
    required this.detailLabels,
    this.maxScore = 100,
    this.valueDisplay,
    this.unit,
  });

  @override
  State<TaqaPillarCard> createState() => _TaqaPillarCardState();
}

class _TaqaPillarCardState extends State<TaqaPillarCard> {
  bool _expanded = false;

  String t(String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    final isDarkCard =
        widget.metricKey == 'training_load' ||
        widget.metricKey == 'nutrition' ||
        widget.metricKey == 'readiness' ||
        widget.metricKey == 'lifestyle_balance';
    final hasDetails =
        widget.detailLabels.isNotEmpty && widget.details.isNotEmpty;
    final scoreDisplay = widget.score == null
        ? "--"
        : widget.valueDisplay ?? widget.score!.round().toString();
    final safeMaxScore = widget.maxScore <= 0 ? 100 : widget.maxScore;
    final barValue = widget.score == null
        ? 0.0
        : (widget.score! / safeMaxScore).clamp(0.0, 1.0);
    final cardBg = isDarkCard ? TaqaUiColors.charcoal : TaqaUiColors.white;
    final textColor = isDarkCard ? TaqaUiColors.white : TaqaUiColors.charcoal;
    final chipBorder = isDarkCard
        ? TaqaUiColors.lightGray.withValues(alpha: 0.6)
        : TaqaUiColors.graphite.withValues(alpha: 0.6);
    final barTrack = isDarkCard
        ? TaqaUiColors.graphite.withValues(alpha: 0.95)
        : TaqaUiColors.lightGray.withValues(alpha: 0.9);
    final barFill = isDarkCard
        ? TaqaUiColors.lightGray.withValues(alpha: 0.85)
        : TaqaUiColors.graphite.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: TaqaUiScale.insetsLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: TaqaUiScale.radius(15),
        ),
        child: Column(
          children: [
            SizedBox(
              height: TaqaUiScale.h(78),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: TaqaUiScale.w(180),
                    height: TaqaUiScale.h(25),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 25 / 15,
                      ),
                    ),
                  ),
                  if (widget.path != null)
                    Positioned(
                      right: 0,
                      top: TaqaUiScale.h(5),
                      child: _PathChip(
                        path: widget.path!,
                        isDark: isDarkCard,
                        borderColor: chipBorder,
                      ),
                    ),
                  if (widget.unit != null && widget.unit!.isNotEmpty)
                    Positioned(
                      left: TaqaUiScale.w(265),
                      top: TaqaUiScale.h(33),
                      width: TaqaUiScale.w(hasDetails ? 32 : 64),
                      height: TaqaUiScale.h(12),
                      child: Text(
                        widget.unit!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(10),
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.55),
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ),
                  Positioned(
                    left: TaqaUiScale.w(265),
                    top: TaqaUiScale.h(48),
                    // Narrower when an arrow is present (hasDetails) so the
                    // two never overlap; full width otherwise since there's
                    // nothing to its right competing for space.
                    width: TaqaUiScale.w(hasDetails ? 32 : 64),
                    height: TaqaUiScale.h(30),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        scoreDisplay,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(25),
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: TaqaUiScale.h(56),
                    width: TaqaUiScale.w(250),
                    height: TaqaUiScale.h(17),
                    child: ClipRRect(
                      borderRadius: TaqaUiScale.radius(9),
                      child: LinearProgressIndicator(
                        value: barValue,
                        backgroundColor: barTrack,
                        valueColor: AlwaysStoppedAnimation(barFill),
                        minHeight: TaqaUiScale.h(17),
                      ),
                    ),
                  ),
                  // Anchored to the card's actual right edge (self-adjusts
                  // to any screen width). The score column above was
                  // narrowed to TaqaUiScale.w(32) so it no longer reaches
                  // far enough right to sit under this arrow.
                  if (hasDetails)
                    Positioned(
                      right: 0,
                      top: TaqaUiScale.h(48),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isDarkCard
                            ? TaqaUiColors.white.withValues(alpha: 0.85)
                            : TaqaUiColors.charcoal.withValues(alpha: 0.85),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            if (_expanded && hasDetails) ...[
              if (_statusMessage() != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _statusMessage()!,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: textColor.withValues(alpha: 0.78),
                      letterSpacing: 0,
                      height: 25 / 15,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: isDarkCard ? TaqaUiColors.charcoal : TaqaUiColors.white,
                  borderRadius: TaqaUiScale.radius(15),
                ),
                child: Column(
                  children: widget.detailLabels.entries
                      .map((entry) {
                        final rawVal = widget.details[entry.key];
                        if (rawVal == null) return const SizedBox.shrink();
                        final val = _formatDetailValue(entry.key, rawVal);
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: TaqaUiScale.h(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _capitalize(entry.value),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(15),
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                  letterSpacing: 0,
                                  height: 25 / 15,
                                ),
                              ),
                              Text(
                                _capitalize(val),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(15),
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                  letterSpacing: 0,
                                  height: 25 / 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _statusMessage() {
    if (widget.metricKey == 'training_load') {
      final note = widget.details['note']?.toString();
      if (note != null && note.isNotEmpty) return note;

      if (widget.path == 'coming_soon') {
        return 'Training Load support for this provider is coming soon.';
      }

      if (widget.score == null) {
        final phaseLabel = widget.details['phase_label']?.toString();
        if (phaseLabel == 'Calibrating') {
          final remaining = widget.details['progress_remaining'];
          final unit = widget.details['progress_unit']?.toString() ?? 'days';
          if (remaining is num) {
            return '$remaining more $unit needed to unlock Training Load.';
          }
          return 'Training Load is calibrating.';
        }
        return t("taqa_training_no_data");
      }

      final status = widget.details['status_label']?.toString();
      if (status != null && status.isNotEmpty) {
        return 'Load status: $status';
      }
    }
    if (widget.metricKey == 'nutrition' && widget.score == null) {
      return t("taqa_nutrition_no_data");
    }
    return null;
  }

  String _formatDetailValue(String key, dynamic rawVal) {
    if (rawVal is bool) {
      return rawVal ? 'Yes' : 'No';
    }
    if (rawVal is num) {
      if (key == 'active_days_7d' || key == 'phase') {
        return rawVal.toInt().toString();
      }
      if (key == 'wow_change_pct') {
        return '${rawVal.toStringAsFixed(1)}%';
      }
      if (key == 'efficiency_ratio') {
        return rawVal.toStringAsFixed(3);
      }
      return rawVal.toStringAsFixed(1);
    }
    return rawVal.toString();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }
}

class _PathChip extends StatelessWidget {
  final String path;
  final bool isDark;
  final Color borderColor;
  const _PathChip({
    required this.path,
    required this.isDark,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isWhoop = path == 'whoop_direct';
    final isFitbit = path == 'fitbit_direct';
    final label = path == 'wearable'
        ? 'WEARABLE'
        : path == 'journal'
        ? 'JOURNAL'
        : path == 'tflu_v1'
        ? 'TFLU'
        : path == 'coming_soon'
        ? 'COMING SOON'
        : path == 'diet_data'
        ? 'DIET'
        : path == 'journal_nutrition'
        ? 'JOURNAL'
        : path == 'whoop_direct'
        ? 'WHOOP DIRECT'
        : path == 'fitbit_direct'
        ? 'FITBIT DIRECT'
        : path == 'samsung_direct'
        ? 'SAMSUNG DIRECT'
        : path == 'samsung_direct_inverted'
        ? 'SAMSUNG DIRECT'
        : path == 'prom_aware_composite'
        ? 'COMPOSITE'
        : path.toUpperCase();
    final chipTextColor = isDark
        ? TaqaUiColors.white
        : TaqaUiColors.unnamedColor1c1d17;
    return Container(
      alignment: Alignment.center,
      padding: TaqaUiScale.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? TaqaUiColors.charcoal : Colors.transparent,
        borderRadius: TaqaUiScale.radius(5),
        border: Border.all(
          color: isDark ? borderColor : TaqaUiColors.unnamedColor1c1d17,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWhoop || isFitbit) ...[
            Image.asset(
              isWhoop ? 'assets/images/whoop.png' : 'assets/images/fitbit.png',
              width: 10,
              height: 10,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              color: chipTextColor,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              height: 10 / 8,
            ),
          ),
        ],
      ),
    );
  }
}
