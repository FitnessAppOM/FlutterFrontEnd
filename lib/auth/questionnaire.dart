import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../widgets/questionnaire/questionnaire_info_chip.dart';
import '../widgets/questionnaire/questionnaire_section_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/questionnaire/questionnaire_form.dart';
import '../services/questionnaire_service.dart';
import '../core/account_storage.dart';
import '../main/main_layout.dart';
import '../widgets/app_toast.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({super.key});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
  automaticallyImplyLeading: false, // no default back button
  title: Text(t.translate("questionnaire_title")),
  centerTitle: true,
),
      backgroundColor: cs.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _started ? _buildFormUI(context) : _buildIntro(context),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate("questionnaire_intro_title"),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.translate("questionnaire_intro_text"),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              QuestionnaireInfoChip(
                icon: Icons.timer_outlined,
                label: t.translate("questionnaire_chip_time"),
              ),
              QuestionnaireInfoChip(
                icon: Icons.person_search_outlined,
                label: t.translate("questionnaire_chip_personal"),
              ),
              QuestionnaireInfoChip(
                icon: Icons.lock_outline,
                label: t.translate("questionnaire_chip_private"),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuestionnaireSectionRow(
                    icon: Icons.monitor_weight_outlined,
                    title: t.translate("section_basics_title"),
                    subtitle: t.translate("section_basics_sub"),
                  ),
                  const SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.flag_outlined,
                    title: t.translate("section_goals_title"),
                    subtitle: t.translate("section_goals_sub"),
                  ),
                  const SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.fitness_center_outlined,
                    title: t.translate("section_training_title"),
                    subtitle: t.translate("section_training_sub"),
                  ),
                  const SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.restaurant_outlined,
                    title: t.translate("section_nutrition_title"),
                    subtitle: t.translate("section_nutrition_sub"),
                  ),
                  const SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.bedtime_outlined,
                    title: t.translate("section_lifestyle_title"),
                    subtitle: t.translate("section_lifestyle_sub"),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: PrimaryWhiteButton(
              onPressed: () {
                setState(() => _started = true);
              },
              child: Text(t.translate("start_questionnaire")),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              t.translate("update_later"),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormUI(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: QuestionnaireForm(
        onSubmit: (values) async {
          try {
            final userId = await AccountStorage.getUserId();
            if (userId == null) {
              AppToast.show(context, t.translate("user_missing"), type: AppToastType.error);
              return;
            }

            final payload = {
              "user_id": userId.toString(),
              ...values,
            };

            await QuestionnaireApi.submitQuestionnaire(payload);

            if (!mounted) return;
            AppToast.show(context, t.translate("save_success"), type: AppToastType.success);
            await AccountStorage.setQuestionnaireDone(true);
            if (!mounted) return;

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainLayout()),
              (route) => false,
            );
          } catch (e) {
            if (!mounted) return;
            AppToast.show(
              context,
              "${t.translate("save_error")}: $e",
              type: AppToastType.error,
            );
          }
        },
      ),
    );
  }
}
