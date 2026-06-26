import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  String title = "Diet Suggestions",
  String? message,
  List<Map<String, dynamic>>? options,
  int? remainingCalories,
  Future<DietRecommendationResult>? optionsFuture,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return _DietRecommendationDialog(
        title: title,
        initialMessage: message ?? _defaultHeaderMessage(remainingCalories),
        initialOptions: options ?? const [],
        optionsFuture: optionsFuture,
      );
    },
  );
}

String _defaultHeaderMessage(int? remainingCalories) {
  if (remainingCalories != null && remainingCalories > 0) {
    return "You have about $remainingCalories kcal left today. "
        "Here are a few ideas to finish your day.";
  }
  return "Here are a few ideas to finish your day.";
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
      future.then((result) {
        if (!mounted) return;
        setState(() {
          _message = result.message.isNotEmpty ? result.message : _message;
          _options = result.options;
          _loadingOptions = false;
        });
      }).catchError((_) {
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
    return Dialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _message,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(height: 14),
              _buildBody(),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingOptions) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Text(
            "Loading suggestions...",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      );
    }

    if (_options.isEmpty) {
      return Text(
        _failed
            ? "Couldn't load suggestions right now. Please try again later."
            : "No suggestions right now.",
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
      );
    }

    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final opt = _options[i];
          final title = (opt["title"] ?? "Option").toString();
          final how = (opt["how_to_eat"] ?? "").toString();
          final cals = opt["estimated_calories"] ?? 0;
          final p = opt["estimated_protein_g"] ?? 0;
          final c = opt["estimated_carbs_g"] ?? 0;
          final f = opt["estimated_fat_g"] ?? 0;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (how.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    how,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  "$cals kcal • P $p • C $c • F $f",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
