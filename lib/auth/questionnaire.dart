import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/questionnaire_info_chip.dart';
import '../widgets/questionnaire_section_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/questionnaire_form.dart';
import '../services/questionnaire_service.dart';
import '../core/account_storage.dart';
import '../widgets/questionnaire_slider_field.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({super.key});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Personalized Form"),
        centerTitle: true,
        leading: _started
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _started = false;
            });
          },
        )
            : null,
      ),
      backgroundColor: colorScheme.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _started ? _buildFormUI(context) : _buildIntro(context),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let’s personalize your plan",
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            "Answer a few questions so we can adapt your workouts and nutrition to your body, lifestyle, and goals.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24.0),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              QuestionnaireInfoChip(
                icon: Icons.timer_outlined,
                label: "Takes ~3–5 min",
              ),
              QuestionnaireInfoChip(
                icon: Icons.person_search_outlined,
                label: "Fully personalized",
              ),
              QuestionnaireInfoChip(
                icon: Icons.lock_outline,
                label: "Your data is private",
              ),
            ],
          ),

          const SizedBox(height: 24.0),

          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  QuestionnaireSectionRow(
                    icon: Icons.monitor_weight_outlined,
                    title: "Basics",
                    subtitle: "Age, height, weight, body type.",
                  ),
                  SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.flag_outlined,
                    title: "Goals",
                    subtitle: "What you want to achieve & by when.",
                  ),
                  SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.fitness_center_outlined,
                    title: "Training",
                    subtitle: "Experience, days per week, style.",
                  ),
                  SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.restaurant_outlined,
                    title: "Nutrition",
                    subtitle: "Diet type, allergies, meals.",
                  ),
                  SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.bedtime_outlined,
                    title: "Lifestyle & Health",
                    subtitle: "Sleep, stress, any conditions.",
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32.0),

          SizedBox(
            width: double.infinity,
            child: PrimaryWhiteButton(
              onPressed: () {
                setState(() => _started = true);
              },
              child: const Text("Start questionnaire"),
            ),
          ),

          const SizedBox(height: 12.0),

          Center(
            child: Text(
              "You can always update your answers later.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: QuestionnaireForm(
        onSubmit: (values) async {
          try {
            final userId = await AccountStorage.getUserId();
            if (userId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User ID missing – login again')),
              );
              return;
            }

            final payload = {
              "user_id": userId.toString(),
              ...values,
            };

            await QuestionnaireApi.submitQuestionnaire(payload);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Questionnaire saved successfully')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },

      ),
    );
  }
}
