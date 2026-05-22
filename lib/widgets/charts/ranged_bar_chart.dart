import 'package:flutter/material.dart';

class RangedBarChartEntry {
  const RangedBarChartEntry({required this.axisLabel, required this.value});

  final String axisLabel;
  final double value;
}

class RangedBarChart extends StatelessWidget {
  const RangedBarChart({
    super.key,
    required this.entries,
    required this.maxValue,
    required this.midValue,
    required this.formatValue,
    required this.gradient,
    required this.selectedGradient,
    this.selectedIndex,
    this.onBarTap,
    this.showAxisLabels = true,
    this.useFixedSlots = false,
    this.barSpacing = 4.0,
    this.minBarWidth = 0.0,
    this.yAxisWidth = 42.0,
    this.yAxisGap = 8.0,
    this.labelHeight = 16.0,
    this.labelGap = 4.0,
    this.gridLineColor,
    this.yAxisTitle,
    this.axisTextColor = Colors.white54,
    this.labelTextColor = Colors.white54,
  });

  final List<RangedBarChartEntry> entries;
  final double maxValue;
  final double midValue;
  final String Function(double value) formatValue;
  final List<Color> gradient;
  final List<Color> selectedGradient;
  final int? selectedIndex;
  final ValueChanged<int>? onBarTap;
  final bool showAxisLabels;
  final bool useFixedSlots;
  final double barSpacing;
  final double minBarWidth;
  final double yAxisWidth;
  final double yAxisGap;
  final double labelHeight;
  final double labelGap;
  final Color? gridLineColor;
  final String? yAxisTitle;
  final Color axisTextColor;
  final Color labelTextColor;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final axisTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: axisTextColor,
      fontSize: 11,
    );
    final labelTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: labelTextColor,
    );
    final lineColor = gridLineColor ?? Colors.white.withValues(alpha: 0.06);

    final chart = LayoutBuilder(
      builder: (context, constraints) {
        final barMaxHeight = showAxisLabels
            ? (constraints.maxHeight - labelHeight - labelGap).clamp(
                0.0,
                double.infinity,
              )
            : constraints.maxHeight;
        final barAreaWidth = (constraints.maxWidth - yAxisWidth - yAxisGap)
            .clamp(0.0, double.infinity);
        final barSlot = useFixedSlots
            ? (barAreaWidth / (entries.isEmpty ? 1 : entries.length))
            : null;
        final barWidth = useFixedSlots
            ? (barSlot! - (barSpacing * 2)).clamp(minBarWidth, double.infinity)
            : null;

        final bars = entries.asMap().entries.map((pair) {
          final index = pair.key;
          final entry = pair.value;
          final isSelected = selectedIndex == index;
          final safeValue = entry.value.isFinite ? entry.value : 0.0;
          final safeMaxValue = maxValue.isFinite && maxValue > 0 ? maxValue : 1.0;
          final heightFactor = (safeValue / safeMaxValue).clamp(0.0, 1.0);
          final label = entry.axisLabel;
          final showLabel = showAxisLabels && label.isNotEmpty;
          final bar = Container(
            height: barMaxHeight * heightFactor,
            width: barWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.75),
                      width: 1.1,
                    )
                  : null,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isSelected ? selectedGradient : gradient,
              ),
            ),
          );

          final content = Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bar,
              if (showAxisLabels) SizedBox(height: labelGap),
              if (showAxisLabels)
                SizedBox(
                  height: labelHeight,
                  child: showLabel
                      ? Text(
                          label,
                          style: labelTextStyle,
                          textAlign: TextAlign.center,
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          );

          final wrapped = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBarTap == null ? null : () => onBarTap!(index),
            child: content,
          );

          if (useFixedSlots) {
            return SizedBox(
              width: barSlot,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: barSpacing),
                child: wrapped,
              ),
            );
          }

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: barSpacing),
              child: wrapped,
            ),
          );
        }).toList();

        double yForValue(num v) {
          final safeMaxValue = maxValue.isFinite && maxValue > 0 ? maxValue : 1.0;
          final safeInput = v.isFinite ? v : 0;
          final ratio = (safeInput / safeMaxValue).clamp(0.0, 1.0);
          return (1.0 - ratio) * barMaxHeight;
        }

        final yAxis = SizedBox(
          width: yAxisWidth,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Text(
                  formatValue(maxValue.isFinite ? maxValue : 0),
                  style: axisTextStyle,
                ),
              ),
              Positioned(
                right: 0,
                top: (yForValue(midValue) - 6).clamp(0.0, barMaxHeight - 12),
                child: Text(
                  formatValue(midValue.isFinite ? midValue : 0),
                  style: axisTextStyle,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(formatValue(0), style: axisTextStyle),
              ),
            ],
          ),
        );

        final barArea = SizedBox(
          height: constraints.maxHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: barMaxHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(height: 1, color: lineColor),
                    Container(height: 1, color: lineColor),
                    Container(height: 1, color: lineColor),
                  ],
                ),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: bars),
            ],
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            yAxis,
            SizedBox(width: yAxisGap),
            Expanded(child: barArea),
          ],
        );
      },
    );

    if ((yAxisTitle ?? '').trim().isEmpty) {
      return chart;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          yAxisTitle!,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 210, child: chart),
      ],
    );
  }
}
