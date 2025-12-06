import 'package:flutter/material.dart';
import '../primary_button.dart';
import '../../localization/app_localizations.dart';
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

  String _t(String key) {
    return AppLocalizations.of(context).translate(key);
  }

  String get _sectionTitle {
    switch (_currentSection) {
      case 0:
        return _t("sec_basic_title");
      case 1:
        return _t("sec_goals_title");
      case 2:
        return _t("sec_training_title");
      case 3:
        return _t("sec_nutrition_title");
      case 4:
        return _t("sec_lifestyle_title");
      case 5:
        return _t("sec_health_title");
      default:
        return "";
    }
  }

  String get _sectionSubtitle {
    switch (_currentSection) {
      case 0:
        return _t("sec_basic_sub");
      case 1:
        return _t("sec_goals_sub");
      case 2:
        return _t("sec_training_sub");
      case 3:
        return _t("sec_nutrition_sub");
      case 4:
        return _t("sec_lifestyle_sub");
      case 5:
        return _t("sec_health_sub");
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
        SnackBar(content: Text(_t("consent_required"))),
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
                "${_t("step")} ${_currentSection + 1} ${_t("of")} $_totalSections",
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
                      child: Text(_t("back")),
                    ),
                  ),
                if (_currentSection > 0) const SizedBox(width: 8),
                Expanded(
                  child: PrimaryWhiteButton(
                    onPressed: _next,
                    child: Text(
                      _currentSection == _totalSections - 1
                          ? _t("finish")
                          : _t("next"),
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

  List<Widget> _buildBasicInfoSection() {
    _values.putIfAbsent("age", () => "25");
    _values.putIfAbsent("height_cm", () => "170");
    _values.putIfAbsent("weight_kg", () => "70");

    return [
      _buildChoiceField(
        label: _t("sex"),
        keyName: "sex",
        options: [_t("male"), _t("female"), _t("prefer_not")],
      ),
      CupertinoPickerField(
        label: _t("age"),
        options: List.generate(83, (i) => (i + 18).toString()),
        initialValue: _values["age"]!,
        onSelected: (v) => _saveField("age", v),
      ),
      GestureDetector(
        onTap: () async {
          final selected = await showHeightPickerPopup(
            context,
            initialHeight: int.tryParse(_values["height_cm"]!) ?? 170,
          );
          if (selected != null) {
            setState(() => _values["height_cm"] = selected.toString());
          }
        },
        child: _simpleFieldRow(_t("height"), "${_values["height_cm"]} cm"),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          final selected = await showWeightPickerPopup(
            context,
            initialWeight: int.tryParse(_values["weight_kg"]!) ?? 70,
          );
          if (selected != null) {
            setState(() => _values["weight_kg"] = selected.toString());
          }
        },
        child: _simpleFieldRow(_t("weight"), "${_values["weight_kg"]} kg"),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildGoalsSection() {
    return [
      _buildChoiceField(
        label: _t("goal_main"),
        keyName: "main_goal",
        options: [
          _t("lose_weight"),
          _t("gain_muscle"),
          _t("improve_endurance"),
          _t("maintain_fitness"),
          _t("improve_health"),
        ],
      ),
      _buildChoiceField(
        label: _t("motivation"),
        keyName: "motivation",
        options: [
          _t("look_better"),
          _t("feel_stronger"),
          _t("health_better"),
          _t("more_energy"),
          _t("mental_wellbeing"),
        ],
      ),
      _buildChoiceField(
        label: _t("important_muscles"),
        keyName: "important_muscles",
        options: [
          _t("arms"),
          _t("shoulders"),
          _t("abs"),
          _t("back"),
          _t("legs"),
          _t("all_body"),
        ],
      ),
      _buildChoiceField(
        label: _t("time_change"),
        keyName: "time_to_change",
        options: ["4", "8", "12", _t("no_timeframe")],
      ),
      _buildChoiceField(
        label: _t("deadline"),
        keyName: "event_deadline",
        options: [
          _t("sport"),
          _t("wedding"),
          _t("birthday"),
          _t("vacation"),
          _t("other"),
          _t("no"),
        ],
      ),
    ];
  }

  List<Widget> _buildTrainingSection() {
    return [
      _buildChoiceField(
        label: _t("body_type"),
        keyName: "body_type",
        options: [_t("slender"), _t("average"), _t("muscular"), _t("heavy")],
      ),
      _buildChoiceField(
        label: _t("fitness_experience"),
        keyName: "fitness_experience",
        options: [
          _t("beginner"),
          _t("intermediate"),
          _t("advanced"),
        ],
      ),
      _buildChoiceField(
        label: _t("training_days"),
        keyName: "training_days",
        options: ["1", "2", "3", "4", "5", "6"],
      ),
      _buildChoiceField(
        label: _t("preferred_time"),
        keyName: "preferred_time",
        options: [
          _t("morning"),
          _t("noon"),
          _t("afternoon"),
          _t("evening"),
          _t("flexible"),
        ],
      ),
      _buildChoiceField(
        label: _t("training_location"),
        keyName: "training_location",
        options: [_t("gym"), _t("home"), _t("hybrid")],
      ),
      _buildChoiceField(
        label: _t("equipment"),
        keyName: "equipment",
        options: [
          _t("dumbbells"),
          _t("barbell"),
          _t("resistance_bands"),
          _t("bodyweight"),
          _t("machines"),
          _t("mix"),
        ],
      ),
      _buildChoiceField(
        label: _t("training_style"),
        keyName: "training_style",
        options: [
          _t("strength"),
          _t("hypertrophy"),
          _t("functional"),
          _t("endurance"),
          _t("hiit"),
          _t("mobility"),
        ],
      ),
      _buildMultiChoiceField(
        label: _t("past_injuries"),
        keyName: "past_injuries",
        options: [
          _t("shoulder"),
          _t("back"),
          _t("knee"),
          _t("elbow"),
          _t("none"),
        ],
      ),
      _buildChoiceField(
        label: _t("train_mode"),
        keyName: "train_mode",
        options: [
          _t("alone"),
          _t("partner"),
          _t("trainer"),
        ],
      ),
      _buildChoiceField(
        label: _t("auto_recovery"),
        keyName: "auto_recovery",
        options: [_t("yes"), _t("no")],
      ),
    ];
  }

  List<Widget> _buildNutritionSection() {
    return [
      _buildChoiceField(
        label: _t("diet_type"),
        keyName: "diet_type",
        options: [
          _t("no_pref"),
          _t("high_protein"),
          _t("low_carb"),
          _t("vegetarian"),
          _t("vegan"),
          _t("fasting"),
          _t("other"),
        ],
      ),
      _buildMultiChoiceField(
        label: _t("allergies"),
        keyName: "allergies",
        options: [
          _t("dairy"),
          _t("gluten"),
          _t("nuts"),
          _t("shellfish"),
          _t("none"),
          _t("other"),
        ],
      ),
      _buildChoiceField(
        label: _t("meals_per_day"),
        keyName: "meals_per_day",
        options: ["2", "3", "4", "5", "6"],
      ),
      _buildChoiceField(
        label: _t("food_habit"),
        keyName: "food_habit",
        options: [_t("cook"), _t("eat_out"), _t("mix")],
      ),
      _buildChoiceField(
        label: _t("kitchen_access"),
        keyName: "kitchen_access",
        options: [_t("yes"), _t("no")],
      ),
      _buildMultiChoiceField(
        label: _t("supplements"),
        keyName: "supplements",
        options: [
          _t("protein"),
          _t("creatine"),
          _t("multivitamin"),
          _t("none"),
          _t("other"),
        ],
      ),
      _buildChoiceField(
        label: _t("water_intake"),
        keyName: "water_intake",
        options: ["<1L", "1–2L", "2–3L", ">3L"],
      ),
      _buildChoiceField(
        label: _t("meal_plan"),
        keyName: "meal_plan",
        options: [_t("low_budget"), _t("moderate"), _t("flexible")],
      ),
    ];
  }

  List<Widget> _buildLifestyleSection() {
    return [
      _buildChoiceField(
        label: _t("daily_activity"),
        keyName: "daily_activity",
        options: [_t("sedentary"), _t("moderate"), _t("active"), _t("highly_active")],
      ),
      _buildChoiceField(
        label: _t("sleep_hours"),
        keyName: "sleep_hours",
        options: ["<6", "6–7", "7–8", ">8"],
      ),
      _buildChoiceField(
        label: _t("sleep_consistency"),
        keyName: "sleep_consistency",
        options: [_t("regular"), _t("irregular")],
      ),
      _buildChoiceField(
        label: _t("wake_feeling"),
        keyName: "wake_feeling",
        options: [_t("tired"), _t("okay"), _t("refreshed")],
      ),
      _buildChoiceField(
        label: _t("stress_level"),
        keyName: "stress_level",
        options: [_t("low"), _t("moderate"), _t("high")],
      ),
    ];
  }

  List<Widget> _buildHealthSettingsSection() {
    return [
      _buildTextField(
        label: _t("chronic_conditions"),
        keyName: "chronic_conditions",
      ),
      _buildChoiceField(
        label: _t("auto_adjust"),
        keyName: "auto_adjust",
        options: [_t("yes"), _t("no")],
      ),
      _buildChoiceField(
        label: _t("consent_tracking"),
        keyName: "consent",
        options: [_t("yes"), _t("no")],
      ),
    ];
  }

  Widget _simpleFieldRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
            return _t("required");
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
        initialValue: current,
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
            return _t("select_option");
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
          return _t("select_one");
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