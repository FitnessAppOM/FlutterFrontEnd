import 'package:flutter/material.dart';
import '../primary_button.dart';
import 'questionnaire_slider_field.dart';
import 'cupertino_picker_field.dart';
import 'height_picker_with_body.dart';
import 'weight_picker_popup.dart';

class QuestionnaireForm extends StatefulWidget {
  const QuestionnaireForm({
    super.key,
    this.onSubmit,
  });

  final void Function(Map<String, String>)? onSubmit;

  @override
  State<QuestionnaireForm> createState() => _QuestionnaireFormState();
}

class _QuestionnaireFormState extends State<QuestionnaireForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _values = {};
  int _currentSection = 0;

  static const _totalSections = 6;

  void _saveField(String key, String? value) {
    _values[key] = value?.trim() ?? '';
  }

  String get _sectionTitle {
    switch (_currentSection) {
      case 0:
        return "Basic Info";
      case 1:
        return "Goals & Motivation";
      case 2:
        return "Training";
      case 3:
        return "Nutrition";
      case 4:
        return "Lifestyle & Recovery";
      case 5:
        return "Health & Settings";
      default:
        return "";
    }
  }

  String get _sectionSubtitle {
    switch (_currentSection) {
      case 0:
        return "Tell us your basic body information.";
      case 1:
        return "What you want to achieve and why.";
      case 2:
        return "How you like to train and what you can do.";
      case 3:
        return "Your diet habits and preferences.";
      case 4:
        return "Your daily routine, sleep and stress.";
      case 5:
        return "Health details and how flexible your plan is.";
      default:
        return "";
    }
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_currentSection < _totalSections - 1) {
      setState(() {
        _currentSection++;
      });
    } else {
      await _submit();
    }
  }

  void _back() {
    if (_currentSection > 0) {
      setState(() {
        _currentSection--;
      });
    }
  }

  Future<void> _submit() async {
    final consent = _values['consent'];

    if (consent == 'No') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need to consent to data collection and tracking to submit this questionnaire.',
          ),
        ),
      );
      return;
    }

    widget.onSubmit?.call(_values);
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sectionTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _sectionSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildCurrentSectionFields(),
            const SizedBox(height: 24),
            Center(
              child: Text(
                "Step ${_currentSection + 1} of $_totalSections",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_currentSection > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: _back,
                      child: const Text("Back"),
                    ),
                  ),
                if (_currentSection > 0) const SizedBox(width: 8),
                Expanded(
                  child: PrimaryWhiteButton(
                    onPressed: _next,
                    child: Text(
                      _currentSection == _totalSections - 1
                          ? "Finish"
                          : "Next",
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCurrentSectionFields() {
    switch (_currentSection) {
      case 0:
        return _buildBasicInfoSection();
      case 1:
        return _buildGoalsSection();
      case 2:
        return _buildTrainingSection();
      case 3:
        return _buildNutritionSection();
      case 4:
        return _buildLifestyleSection();
      case 5:
        return _buildHealthSettingsSection();
      default:
        return [];
    }
  }

  // ---------------- BASIC INFO (age, height, weight) ----------------
  List<Widget> _buildBasicInfoSection() {
    // Ensure required backend fields always exist
    _values.putIfAbsent("age", () => "25");
    _values.putIfAbsent("height_cm", () => "170");
    _values.putIfAbsent("weight_kg", () => "70");

    return [
      _buildChoiceField(
        label: "Sex",
        keyName: "sex",
        options: const ["Male", "Female", "Prefer not to say"],
      ),

      // AGE (Cupertino wheel)
      CupertinoPickerField(
        label: "Age",
        options: List.generate(83, (i) => (i + 18).toString()), // 18–100
        initialValue: _values["age"]!,
        onSelected: (v) => _saveField("age", v),
      ),

      // HEIGHT
      GestureDetector(
        onTap: () async {
          final selected = await showHeightPickerPopup(
            context,
            initialHeight: int.tryParse(_values["height_cm"]!) ?? 170,
          );

          if (selected != null) {
            setState(() {
              _values["height_cm"] = selected.toString();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Height"),
              Text(
                "${_values["height_cm"]} cm",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // WEIGHT
      GestureDetector(
        onTap: () async {
          final selected = await showWeightPickerPopup(
            context,
            initialWeight: int.tryParse(_values["weight_kg"]!) ?? 70,
          );

          if (selected != null) {
            setState(() {
              _values["weight_kg"] = selected.toString();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Weight"),
              Text(
                "${_values["weight_kg"]} kg",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  // ---------------- GOALS ----------------
  List<Widget> _buildGoalsSection() {
    return [
      _buildChoiceField(
        label: "What is your main goal?",
        keyName: "main_goal",
        options: const [
          "Lose weight",
          "Gain muscle",
          "Improve endurance",
          "Maintain fitness",
          "Improve health",
        ],
      ),
      _buildChoiceField(
        label: "What motivates you most?",
        keyName: "motivation",
        options: const [
          "Look better",
          "Feel stronger",
          "Improve health",
          "Increase energy",
          "Mental well-being",
        ],
      ),
      _buildChoiceField(
        label: "Which muscles are most important to you?",
        keyName: "important_muscles",
        options: const [
          "Arms",
          "Shoulders",
          "Abs",
          "Back",
          "Legs",
          "All body",
        ],
      ),
      _buildChoiceField(
        label: "How soon do you want to see change?",
        keyName: "time_to_change",
        options: const ["4 weeks", "8 weeks", "12 weeks", "No timeframe"],
      ),
      _buildChoiceField(
        label: "Do you have a deadline?",
        keyName: "event_deadline",
        options: const [
          "Yes – Sporting",
          "Wedding",
          "Birthday",
          "Vacation",
          "Other",
          "No",
        ],
      ),
    ];
  }

  // ---------------- TRAINING ----------------
  List<Widget> _buildTrainingSection() {
    return [
      _buildChoiceField(
        label: "Current body type",
        keyName: "body_type",
        options: const ["Slender", "Average", "Muscular", "Heavy"],
      ),
      _buildChoiceField(
        label: "Fitness experience",
        keyName: "fitness_experience",
        options: const [
          "Beginner (<6 months)",
          "Intermediate (6–24 months)",
          "Advanced (>2 years)",
        ],
      ),
      _buildChoiceField(
        label: "Training days per week",
        keyName: "training_days",
        options: const ["1", "2", "3", "4", "5", "6"],
      ),
      _buildChoiceField(
        label: "Preferred time",
        keyName: "preferred_time",
        options: const [
          "Morning",
          "Noon",
          "Afternoon",
          "Evening",
          "Flexible",
        ],
      ),
      _buildChoiceField(
        label: "Where do you train?",
        keyName: "training_location",
        options: const ["Gym", "Home", "Hybrid"],
      ),
      _buildChoiceField(
        label: "Equipment access",
        keyName: "equipment",
        options: const [
          "Dumbbells",
          "Barbell",
          "Resistance bands",
          "Bodyweight only",
          "Machines",
          "Mix",
        ],
      ),
      _buildChoiceField(
        label: "Preferred training style",
        keyName: "training_style",
        options: const [
          "Strength",
          "Hypertrophy",
          "Functional",
          "Endurance",
          "HIIT",
          "Mobility",
        ],
      ),
      _buildMultiChoiceField(
        label: "Past injuries",
        keyName: "past_injuries",
        options: const [
          "Shoulder",
          "Back",
          "Knee",
          "Elbow",
          "None",
        ],
      ),
      _buildChoiceField(
        label: "Train mode",
        keyName: "train_mode",
        options: const [
          "Alone",
          "With partner",
          "With trainer",
        ],
      ),
      _buildChoiceField(
        label: "Include recovery?",
        keyName: "auto_recovery",
        options: const ["Yes", "No"],
      ),
    ];
  }

  // ---------------- NUTRITION ----------------
  List<Widget> _buildNutritionSection() {
    return [
      _buildChoiceField(
        label: "Preferred diet",
        keyName: "diet_type",
        options: const [
          "No preference",
          "High protein",
          "Low carb",
          "Vegetarian",
          "Vegan",
          "Intermittent fasting",
          "Other",
        ],
      ),
      _buildMultiChoiceField(
        label: "Allergies",
        keyName: "allergies",
        options: const [
          "Dairy",
          "Gluten",
          "Nuts",
          "Shellfish",
          "None",
          "Other",
        ],
      ),
      _buildChoiceField(
        label: "Meals per day",
        keyName: "meals_per_day",
        options: const ["2", "3", "4", "5", "6"],
      ),
      _buildChoiceField(
        label: "Food habit",
        keyName: "food_habit",
        options: const ["Mostly cook", "Mostly eat out", "Mix"],
      ),
      _buildChoiceField(
        label: "Kitchen access",
        keyName: "kitchen_access",
        options: const ["Yes", "No"],
      ),
      _buildMultiChoiceField(
        label: "Supplements",
        keyName: "supplements",
        options: const [
          "Protein",
          "Creatine",
          "Multivitamin",
          "None",
          "Other",
        ],
      ),
      _buildChoiceField(
        label: "Daily water intake",
        keyName: "water_intake",
        options: const ["<1L", "1–2L", "2–3L", ">3L"],
      ),
      _buildChoiceField(
        label: "Meal plan type",
        keyName: "meal_plan",
        options: const ["Low budget", "Moderate", "Flexible"],
      ),
    ];
  }

  // ---------------- LIFESTYLE ----------------
  List<Widget> _buildLifestyleSection() {
    return [
      _buildChoiceField(
        label: "Daily activity level",
        keyName: "daily_activity",
        options: const [
          "Sedentary (desk job)",
          "Moderate",
          "Active",
          "Highly physical",
        ],
      ),
      _buildChoiceField(
        label: "Sleep duration",
        keyName: "sleep_hours",
        options: const [
          "<6 hours",
          "6–7 hours",
          "7–8 hours",
          ">8 hours",
        ],
      ),
      _buildChoiceField(
        label: "Sleep consistency",
        keyName: "sleep_consistency",
        options: const ["Regular", "Irregular"],
      ),
      _buildChoiceField(
        label: "Wake feeling",
        keyName: "wake_feeling",
        options: const ["Tired", "Okay", "Refreshed"],
      ),
      _buildChoiceField(
        label: "Stress level",
        keyName: "stress_level",
        options: const ["Low", "Moderate", "High"],
      ),
    ];
  }

  // ---------------- HEALTH & SETTINGS ----------------
  List<Widget> _buildHealthSettingsSection() {
    return [
      _buildTextField(
        label: "Chronic conditions",
        keyName: "chronic_conditions",
      ),
      _buildChoiceField(
        label: "Auto-adjust weekly?",
        keyName: "auto_adjust",
        options: const ["Yes", "No"],
      ),
      _buildChoiceField(
        label: "Consent to tracking?",
        keyName: "consent",
        options: const ["Yes", "No"],
      ),
    ];
  }

  Widget _buildTextField({
    required String label,
    required String keyName,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        key: ValueKey(keyName),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "This field is required";
          }
          return null;
        },
        onSaved: (val) => _saveField(keyName, val),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildChoiceField({
    required String label,
    required String keyName,
    required List<String> options,
  }) {
    final theme = Theme.of(context);
    final current = _values[keyName];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        key: ValueKey(keyName),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: current,
        items: options
            .map(
              (o) => DropdownMenuItem<String>(
            value: o,
            child: Text(o, style: theme.textTheme.bodyMedium),
          ),
        )
            .toList(),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please select an option";
          }
          return null;
        },
        onChanged: (val) => _saveField(keyName, val),
        onSaved: (val) => _saveField(keyName, val),
      ),
    );
  }

  Widget _buildMultiChoiceField({
    required String label,
    required String keyName,
    required List<String> options,
  }) {
    final theme = Theme.of(context);

    return FormField<String>(
      key: ValueKey(keyName),
      initialValue: _values[keyName] ?? '',
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Please select at least one option";
        }
        return null;
      },
      onSaved: (value) => _saveField(keyName, value),
      builder: (state) {
        final raw = state.value ?? '';
        final selected = <String>{
          if (raw.isNotEmpty) ...raw.split(', '),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: options.map((o) {
                  final isSelected = selected.contains(o);
                  return FilterChip(
                    label: Text(o),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          selected.add(o);
                        } else {
                          selected.remove(o);
                        }
                        state.didChange(selected.join(', '));
                      });
                    },
                  );
                }).toList(),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    state.errorText ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
