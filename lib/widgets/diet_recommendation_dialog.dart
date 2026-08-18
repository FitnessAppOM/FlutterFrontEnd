import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_popup_guard.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

/// Result of the recommendation fetch, surfaced to the dialog so it can swap the
/// inline loader for real options (or a graceful message) without ever blocking
/// on a blank "please wait" screen.
class DietRecommendationResult {
  const DietRecommendationResult({
    required this.message,
    required this.options,
  });

  final String message;
  final List<Map<String, dynamic>> options;
}

/// Single dialog that opens instantly. If [remainingCalories] is known we show
/// the "you have X kcal left" header right away and load the food options inline
/// from [optionsFuture]; otherwise we briefly show a spinner until it resolves.
Future<void> showDietRecommendationDialog({
  required BuildContext context,
  String? title,
  String? message,
  List<Map<String, dynamic>>? options,
  int? remainingCalories,
  Future<DietRecommendationResult>? optionsFuture,
}) {
  final t = AppLocalizations.of(context);
  return TaqaPopupGuard.dialogVoid(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      return _DietRecommendationDialog(
        title: title ?? t.translate('diet_suggestions_title'),
        initialMessage: message ?? _defaultHeaderMessage(t, remainingCalories),
        initialOptions: options ?? const [],
        optionsFuture: optionsFuture,
      );
    },
  );
}

String _defaultHeaderMessage(AppLocalizations t, int? remainingCalories) {
  if (remainingCalories != null && remainingCalories > 0) {
    return t
        .translate('diet_suggestions_remaining_message')
        .replaceAll('{calories}', '$remainingCalories');
  }
  return t.translate('diet_suggestions_default_message');
}

class _DietRecommendationDialog extends StatefulWidget {
  const _DietRecommendationDialog({
    required this.title,
    required this.initialMessage,
    required this.initialOptions,
    required this.optionsFuture,
  });

  final String title;
  final String initialMessage;
  final List<Map<String, dynamic>> initialOptions;
  final Future<DietRecommendationResult>? optionsFuture;

  @override
  State<_DietRecommendationDialog> createState() =>
      _DietRecommendationDialogState();
}

class _DietRecommendationDialogState extends State<_DietRecommendationDialog> {
  late String _message;
  late List<Map<String, dynamic>> _options;
  late bool _loadingOptions;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    _options = widget.initialOptions;
    _loadingOptions = widget.optionsFuture != null && _options.isEmpty;

    final future = widget.optionsFuture;
    if (future != null) {
      future
          .then((result) {
            if (!mounted) return;
            setState(() {
              _message = result.message.isNotEmpty ? result.message : _message;
              _options = result.options;
              _loadingOptions = false;
            });
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() {
              _loadingOptions = false;
              _failed = true;
            });
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return TaqaPopupDialog(
      maxHeightFactor: 0.82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(15),
              height: 25 / 15,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          Text(
            _message,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
              fontSize: TaqaUiScale.sp(13),
              height: 18 / 13,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          _buildBody(),
          SizedBox(height: TaqaUiScale.h(16)),
          TaqaTextActionButton(
            label: t.translate('diet_suggestions_close'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final t = AppLocalizations.of(context);
    if (_loadingOptions) {
      return Container(
        width: double.infinity,
        padding: TaqaUiScale.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: TaqaUiColors.lightGray.withValues(alpha: 0.45),
          borderRadius: TaqaUiScale.radius(10),
        ),
        child: Row(
          children: [
            const TaqaLoadingIndicator(size: 16, color: TaqaUiColors.charcoal),
            SizedBox(width: TaqaUiScale.w(10)),
            Expanded(
              child: Text(
                t.translate('diet_suggestions_loading'),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                  fontSize: TaqaUiScale.sp(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_options.isEmpty) {
      return Container(
        width: double.infinity,
        padding: TaqaUiScale.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: TaqaUiColors.lightGray.withValues(alpha: 0.45),
          borderRadius: TaqaUiScale.radius(10),
        ),
        child: Text(
          _failed
              ? t.translate('diet_suggestions_failed')
              : t.translate('diet_suggestions_empty'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
            fontSize: TaqaUiScale.sp(12),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) SizedBox(height: TaqaUiScale.h(10)),
          _buildOptionCard(t, _options[i]),
        ],
      ],
    );
  }

  Widget _buildOptionCard(AppLocalizations t, Map<String, dynamic> option) {
    final title = (option['title'] ?? t.translate('diet_suggestions_option'))
        .toString();
    final how = (option['how_to_eat'] ?? '').toString();
    final cals = option['estimated_calories'] ?? 0;
    final p = option['estimated_protein_g'] ?? 0;
    final c = option['estimated_carbs_g'] ?? 0;
    final f = option['estimated_fat_g'] ?? 0;
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.lightGray.withValues(alpha: 0.45),
        borderRadius: TaqaUiScale.radius(10),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(14),
            ),
          ),
          if (how.isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(6)),
            Text(
              how,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                fontSize: TaqaUiScale.sp(12),
              ),
            ),
          ],
          SizedBox(height: TaqaUiScale.h(8)),
          Text(
            t
                .translate('diet_suggestions_macros')
                .replaceAll('{calories}', '$cals')
                .replaceAll('{protein}', '$p')
                .replaceAll('{carbs}', '$c')
                .replaceAll('{fat}', '$f'),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
              fontSize: TaqaUiScale.sp(9),
              height: 12 / 9,
            ),
          ),
        ],
      ),
    );
  }
}
