import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaClientDashboardCard extends StatelessWidget {
  const TaqaClientDashboardCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = 14,
    this.radius = 15,
    this.minHeight,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double padding;
  final double radius;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final borderRadius = TaqaUiScale.radius(radius);
    final ink = Ink(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(
        TaqaUiScale.w(padding),
        TaqaUiScale.h(padding),
        TaqaUiScale.w(padding),
        TaqaUiScale.h(padding),
      ),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: borderRadius,
      ),
      child: child,
    );
    final content = minHeight == null
        ? ink
        : ConstrainedBox(
            constraints: BoxConstraints(minHeight: TaqaUiScale.h(minHeight!)),
            child: ink,
          );

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}

class TaqaClientDashboardTitleText extends StatelessWidget {
  const TaqaClientDashboardTitleText(
    this.text, {
    super.key,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        color: TaqaUiColors.charcoal,
        fontFamily: TaqaUiFontFamilies.interTight,
        fontWeight: FontWeight.w700,
        fontSize: TaqaUiScale.sp(15),
        height: 25 / 15,
        letterSpacing: 0,
      ),
    );
  }
}

class TaqaClientDashboardBodyText extends StatelessWidget {
  const TaqaClientDashboardBodyText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.color,
  });

  final String text;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        color: color ?? TaqaUiColors.charcoal,
        fontFamily: TaqaUiFontFamilies.interTight,
        fontSize: TaqaUiScale.sp(15),
        fontWeight: FontWeight.w400,
        height: 18 / 15,
        letterSpacing: 0,
      ),
    );
  }
}

class TaqaClientDashboardNavigationCard extends StatelessWidget {
  const TaqaClientDashboardNavigationCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
    this.noticeText,
    this.statusText,
    this.content,
    this.loading = false,
    this.showChevron = true,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;
  final String? noticeText;
  final String? statusText;
  final Widget? content;
  final bool loading;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return TaqaClientDashboardCard(
      onTap: loading ? null : onTap,
      minHeight: 79,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: TaqaClientDashboardTitleText(title)),
              if (loading)
                SizedBox(
                  width: TaqaUiScale.w(16),
                  height: TaqaUiScale.h(16),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: TaqaUiColors.charcoal,
                  size: TaqaUiScale.w(20),
                ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: TaqaUiScale.h(33)),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: TaqaClientDashboardBodyText(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if ((noticeText ?? '').trim().isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(6)),
            TaqaClientAlertText(text: noticeText!),
          ],
          if ((statusText ?? '').trim().isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(6)),
            TaqaClientAlertText(text: statusText!),
          ],
          if (content != null) ...[
            SizedBox(height: TaqaUiScale.h(8)),
            content!,
          ],
        ],
      ),
    );
  }
}

class TaqaClientAlertText extends StatelessWidget {
  const TaqaClientAlertText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: TaqaUiScale.w(6),
          height: TaqaUiScale.h(6),
          decoration: const BoxDecoration(
            color: TaqaUiColors.recordRed,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: TaqaUiScale.w(4)),
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TaqaUiColors.recordRed,
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              height: 18 / 8,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class TaqaClientDashboardAction extends StatelessWidget {
  const TaqaClientDashboardAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: TaqaUiScale.radius(5),
        child: Container(
          height: TaqaUiScale.h(34),
          padding: TaqaUiScale.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: TaqaUiScale.radius(5),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: TaqaUiScale.w(14),
                  height: TaqaUiScale.h(14),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: TaqaUiScale.w(16), color: Colors.white),
              SizedBox(width: TaqaUiScale.w(6)),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: TaqaUiScale.sp(8),
                  height: 10 / 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaqaClientDashboardStatusPill extends StatelessWidget {
  const TaqaClientDashboardStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: TaqaUiScale.radius(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
          fontWeight: FontWeight.w400,
          fontSize: TaqaUiScale.sp(8),
          height: 10 / 8,
          textBaseline: TextBaseline.alphabetic,
        ),
      ),
    );
  }
}

class TaqaClientActivityStatus extends StatelessWidget {
  const TaqaClientActivityStatus({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: TaqaUiScale.w(6),
          height: TaqaUiScale.h(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: TaqaUiScale.r(5),
              ),
            ],
          ),
        ),
        SizedBox(width: TaqaUiScale.w(4)),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
            fontSize: TaqaUiScale.sp(8),
            fontWeight: FontWeight.w400,
            height: 10 / 8,
          ),
        ),
      ],
    );
  }
}

class TaqaClientDashboardInfoRow extends StatelessWidget {
  const TaqaClientDashboardInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: TaqaUiColors.charcoal.withValues(alpha: 0.62),
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 18 / 15,
              letterSpacing: 0,
            ),
          ),
        ),
        SizedBox(width: TaqaUiScale.w(8)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: TaqaUiColors.charcoal,
              fontFamily: TaqaUiFontFamilies.interTight,
              fontWeight: FontWeight.w400,
              fontSize: TaqaUiScale.sp(15),
              height: 18 / 15,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class TaqaClientAiReviewCard extends StatelessWidget {
  const TaqaClientAiReviewCard({
    super.key,
    required this.weekStart,
    required this.itemCount,
    required this.status,
    required this.onTap,
    this.summary,
  });

  final String? weekStart;
  final int itemCount;
  final String status;
  final String? summary;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (status) {
      case 'applied':
        return AppColors.successGreen;
      case 'failed':
        return AppColors.errorRed;
      case 'pending_expert':
        return const Color(0xFF5FD8FF);
      case 'reviewed':
        return AppColors.accent;
      default:
        return Colors.white54;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'pending_expert':
        return 'Pending review';
      case 'reviewed':
        return 'Ready to apply';
      case 'applied':
        return 'Applied';
      case 'failed':
        return 'Needs retry';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TaqaClientDashboardCard(
      onTap: onTap,
      padding: 10,
      radius: 10,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week ${weekStart ?? '-'}',
                  style: TextStyle(
                    color: TaqaUiColors.charcoal,
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontWeight: FontWeight.w700,
                    fontSize: TaqaUiScale.sp(14),
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(4)),
                Text(
                  '$itemCount suggestions',
                  style: TextStyle(
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.62),
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(14),
                  ),
                ),
                if ((summary ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: TaqaUiScale.h(6)),
                  Text(
                    summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.72),
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(14),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: TaqaUiScale.w(10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TaqaClientDashboardStatusPill(
                label: _statusLabel,
                color: _statusColor,
              ),
              SizedBox(height: TaqaUiScale.h(8)),
              Icon(
                Icons.chevron_right,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.38),
                size: TaqaUiScale.w(20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TaqaAudioWaveBars extends StatefulWidget {
  const TaqaAudioWaveBars({
    super.key,
    required this.color,
    this.barCount = 5,
    this.minHeight = 4,
    this.maxHeight = 12,
    this.barWidth = 3,
    this.gap = 2,
  });

  final Color color;
  final int barCount;
  final double minHeight;
  final double maxHeight;
  final double barWidth;
  final double gap;

  @override
  State<TaqaAudioWaveBars> createState() => _TaqaAudioWaveBarsState();
}

class _TaqaAudioWaveBarsState extends State<TaqaAudioWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * math.pi * 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(widget.barCount, (index) {
            final phase = t + (index * 0.7);
            final level = (math.sin(phase) + 1) / 2;
            final height =
                TaqaUiScale.h(widget.minHeight) +
                TaqaUiScale.h(widget.maxHeight - widget.minHeight) * level;
            return Padding(
              padding: EdgeInsetsDirectional.only(
                end: index == widget.barCount - 1
                    ? 0
                    : TaqaUiScale.w(widget.gap),
              ),
              child: Container(
                width: TaqaUiScale.w(widget.barWidth),
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: TaqaUiScale.radius(999),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
