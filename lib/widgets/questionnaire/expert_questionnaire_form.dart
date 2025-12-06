import 'package:flutter/material.dart';
import '../primary_button.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';

class ExpertQuestionnaireForm extends StatelessWidget {
  const ExpertQuestionnaireForm({
    super.key,
    required this.onSubmit,
    required this.submitting,
  });

  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate("expert_placeholder_title"),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          t.translate("expert_placeholder_desc"),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textDim,
              ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.greyDark.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.greyDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate("expert_placeholder_block_title"),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                t.translate("expert_placeholder_block_desc"),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textDim,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: PrimaryWhiteButton(
            onPressed: onSubmit,
            child: submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(t.translate("expert_questionnaire_submit")),
          ),
        ),
      ],
    );
  }
}
