import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Compact three-position date carousel for expert/client weekly views.
class TaqaDateCarouselSwitcher extends StatelessWidget {
  const TaqaDateCarouselSwitcher({
    super.key,
    required this.previousDate,
    required this.selectedDate,
    required this.nextDate,
    required this.onPrevious,
    required this.onSelected,
    required this.onNext,
    this.loading = false,
    this.textColor = TaqaUiColors.charcoal,
  });

  final DateTime previousDate;
  final DateTime selectedDate;
  final DateTime nextDate;
  final VoidCallback? onPrevious;
  final VoidCallback? onSelected;
  final VoidCallback? onNext;
  final bool loading;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    Widget dateButton({
      required DateTime date,
      required VoidCallback? onTap,
      required double opacity,
    }) {
      return Opacity(
        opacity: opacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onTap,
            child: SizedBox(
              width: TaqaUiScale.w(62),
              height: TaqaUiScale.h(32),
              child: Center(
                child: Text(
                  DateFormat('dd MMM').format(date).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                    fontSize: TaqaUiScale.sp(8),
                    fontWeight: FontWeight.w400,
                    height: 10 / 8,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: TaqaUiScale.h(40),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: TaqaUiScale.w(-11),
            top: TaqaUiScale.h(4),
            child: dateButton(
              date: previousDate,
              onTap: onPrevious,
              opacity: 0.5,
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: loading
                ? SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textColor,
                        ),
                      ),
                    ),
                  )
                : dateButton(date: selectedDate, onTap: onSelected, opacity: 1),
          ),
          Positioned(
            right: TaqaUiScale.w(-11),
            top: TaqaUiScale.h(4),
            child: dateButton(date: nextDate, onTap: onNext, opacity: 0.5),
          ),
        ],
      ),
    );
  }
}
