import 'package:flutter/material.dart';
import '../primary_button.dart';
import '../../localization/app_localizations.dart';
import 'cupertino_picker_field.dart';
import 'height_picker_with_body.dart';
import 'weight_picker_popup.dart';
import '../app_toast.dart';
import '../../services/affiliation_service.dart';
import '../../services/university_service.dart';


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
  final Map<String, TextEditingController> _otherControllers = {};
  int _currentSection = 0;
  final TextEditingController _affiliationOtherCtrl = TextEditingController();
  final TextEditingController _chronicCtrl = TextEditingController();

  static const _totalSections = 7;
  List<String> _affiliationCategories = [];
  List<Map<String, dynamic>> _affiliations = [];
  String? _selectedAffiliationCategory;
  bool _affiliationsLoading = false;
  String? _affiliationError;
  bool? _isPhysicalRehab;
  String? get _affiliationChoice => _values["affiliation_choice"];
  bool? _isUniversityStudent;
  List<Map<String, dynamic>> _universities = [];
  bool _universitiesLoading = false;
  String? _selectedUniversityId;


  @override
  void initState() {
    super.initState();
    _loadAffiliationCategories();
  }

  @override
  void dispose() {
    _affiliationOtherCtrl.dispose();
    for (final c in _otherControllers.values) {
      c.dispose();
    }
    _chronicCtrl.dispose();
    super.dispose();
  }

  void _saveField(String key, String? value) {
    _values[key] = value?.trim() ?? '';

    if (key == "is_physical_rehabilitation") {
      final yes = _t("yes");

      setState(() {
        _isPhysicalRehab = value == yes;

        if (_isPhysicalRehab == false) {
          _selectedAffiliationCategory = null;
          _affiliations = [];
          _values.remove("affiliation_id");
          _values.remove("affiliation_other_text");
          _affiliationOtherCtrl.clear();
        }
      });

      _loadAffiliationCategories();
    }if (key == "is_university_student") {
      final yes = _t("yes");

      setState(() {
        _isUniversityStudent = value == yes;

        if (_isUniversityStudent == false) {
          _selectedUniversityId = null;
          _values.remove("university_id");
        }
      });

      if (_isUniversityStudent == true) {
        _loadUniversities();
      }
    }

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
        return _t("sec_affiliation_title");
      case 6:
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
        return _t("sec_affiliation_sub");
      case 6:
        return _t("sec_health_sub");
      default:
        return "";
    }
  }

  Future<void> _loadAffiliationCategories() async {
    try {
      final categories = await AffiliationApi.fetchCategories();
      if (!mounted) return;

      setState(() {
        _affiliationCategories = categories.where((c) {
          if (_isOther(c)) return false;

          final isGym = _norm(c) == _norm(_t("gym"));
          final isHospital = _norm(c) == _norm(_t("hospital"));

          if (_isPhysicalRehab == true) {
            return isGym || isHospital;
          }
          return isGym;
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _affiliationError = _t("affiliation_load_error");
      });
    }
  }


  Future<void> _loadAffiliationsForCategory(String category) async {
    setState(() {
      _affiliationsLoading = true;
      _affiliationError = null;
    });

    try {
      final items = await AffiliationApi.fetchByCategory(category);
      if (!mounted) return;
      setState(() {
        _affiliations =
            items.where((item) => !_isOther(item["name"]?.toString() ?? "")).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _affiliationError = _t("affiliation_load_error");
        _affiliations = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _affiliationsLoading = false;
        });
      }
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
  Future<void> _loadUniversities() async {
    setState(() {
      _universitiesLoading = true;
    });

    try {
      final data = await UniversityService.fetchUniversities();
      if (!mounted) return;

      setState(() {
        _universities = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _universities = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _universitiesLoading = false;
        });
      }
    }
  }


  Future<void> _submit() async {
    final consent = _values['consent'];

    if (consent == 'No') {
      if (!mounted) return;
      AppToast.show(
        context,
        _t("consent_required"),
        type: AppToastType.error,
      );
      return;
    }

    final cleanedValues = Map<String, String>.from(_values);
    final affiliationId = (_values['affiliation_id'] ?? '').trim();
    final affiliationOther = (_values['affiliation_other_text'] ?? '').trim();
    final affiliationChoice = _affiliationChoice;

    if (affiliationChoice == _t("yes")) {
      if (affiliationId.isEmpty && affiliationOther.isEmpty) {
        if (!mounted) return;
        AppToast.show(
          context,
          _t("affiliation_required"),
          type: AppToastType.error,
        );
        return;
      }

      if (affiliationId.isNotEmpty) {
        cleanedValues['affiliation_id'] = affiliationId;
        cleanedValues.remove('affiliation_other_text');
      } else {
        cleanedValues.remove('affiliation_id');
        cleanedValues['affiliation_other_text'] = affiliationOther;
      }
    } else if (affiliationChoice == _t("no")) {
      cleanedValues.remove('affiliation_id');
      cleanedValues['affiliation_other_text'] = "none";
    } else {
      if (!mounted) return;
      AppToast.show(
        context,
        _t("affiliation_required"),
        type: AppToastType.error,
      );
      return;
    }

    const singleChoiceOptions = {
      "sex": ["male", "female", "prefer_not"],
      "main_goal": ["lose_weight", "gain_muscle", "improve_endurance", "maintain_fitness", "improve_health"],
      "motivation": ["look_better", "feel_stronger", "health_better", "more_energy", "mental_wellbeing"],
      "important_muscles": ["arms", "shoulders", "abs", "back", "legs", "all_body"],
      "time_to_change": ["4", "8", "12", "no_timeframe"],
      "event_deadline": ["sport", "wedding", "birthday", "vacation", "other", "no"],
      "body_type": ["slender", "average", "muscular", "heavy"],
      "fitness_experience": ["beginner", "intermediate", "advanced"],
      "training_days": ["1", "2", "3", "4", "5", "6"],
      "preferred_time": ["morning", "noon", "afternoon", "evening", "flexible"],
      "training_location": ["gym", "home", "hybrid"],
      "equipment": ["dumbbells", "barbell", "resistance_bands", "bodyweight", "machines", "mix"],
      "training_style": ["strength", "hypertrophy", "functional", "endurance", "hiit", "mobility"],
      "train_mode": ["alone", "partner", "trainer"],
      "auto_recovery": ["yes", "no"],
      "diet_type": ["no_pref", "high_protein", "low_carb", "vegetarian", "vegan", "fasting", "other"],
      "meals_per_day": ["2", "3", "4", "5", "6"],
      "food_habit": ["cook", "eat_out", "mix"],
      "kitchen_access": ["yes", "no"],
      "water_intake": ["<1l", "1–2l", "2–3l", ">3l"],
      "meal_plan": ["low_budget", "moderate", "flexible"],
      "daily_activity": ["sedentary", "moderate", "active", "highly_active"],
      "sleep_hours": ["<6", "6–7", "7–8", ">8"],
      "sleep_consistency": ["regular", "irregular"],
      "wake_feeling": ["tired", "okay", "refreshed"],
      "stress_level": ["low", "moderate", "high"],
      "auto_adjust": ["yes", "no"],
      "consent": ["yes", "no"],
    };

    const multiChoiceOptions = {
      "past_injuries": ["shoulder", "back", "knee", "elbow", "none"],
      "allergies": ["dairy", "gluten", "nuts", "shellfish", "none", "other"],
      "supplements": ["protein", "creatine", "multivitamin", "none", "other"],
    };

    singleChoiceOptions.forEach((field, options) {
      if (cleanedValues.containsKey(field)) {
        final v = cleanedValues[field]?.trim() ?? "";
        if (v.isEmpty) return;
        cleanedValues[field] = _toEnglishChoice(v, options);
      }
    });

    multiChoiceOptions.forEach((field, options) {
      if (cleanedValues.containsKey(field)) {
        final v = cleanedValues[field]?.trim() ?? "";
        if (v.isEmpty) return;
        cleanedValues[field] = _toEnglishMulti(v, options);
      }
    });

    final chronicKey = "chronic_conditions";
    final chronicNone = _t("chronic_none_value").trim().toLowerCase();
    if (cleanedValues.containsKey(chronicKey)) {
      final val = cleanedValues[chronicKey]?.trim().toLowerCase() ?? "";
      if (val == chronicNone) {
        cleanedValues[chronicKey] = "none";
      }
    }
    if (affiliationChoice == _t("yes") &&
        affiliationId == "custom" &&
        affiliationOther.isNotEmpty) {
      try {
        await AffiliationApi.requestAffiliation(
          name: affiliationOther,
          category: _selectedAffiliationCategory ?? "gym",
          source: "user",
        );
      } catch (_) {
        // silent fail — questionnaire should still submit
      }
    }
    if (cleanedValues['affiliation_id'] == "custom") {
      cleanedValues.remove('affiliation_id');
    }

    widget.onSubmit?.call(cleanedValues);
    if (!mounted) return;
  }

  bool _isOther(String value) => value.trim().toLowerCase() == "other";

  String _norm(String value) => value
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll('–', ' ')
      .trim();

  String _toEnglishChoice(String value, List<String> keys) {
    final normalized = _norm(value);
    for (final key in keys) {
      if (normalized == _norm(key) || normalized == _norm(_t(key))) {
        return key;
      }
    }
    return value;
  }

  String _toEnglishMulti(String value, List<String> keys) {
    if (value.trim().isEmpty) return value;
    final parts = value
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => _toEnglishChoice(p, keys))
        .toSet();
    return parts.join(", ");
  }

  TextEditingController _otherControllerFor(String key) {
    return _otherControllers.putIfAbsent(key, () => TextEditingController());
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
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildCurrentSectionFields(),
            const SizedBox(height: 24),
            Center(
              child: Text(
                "${_t("step")} ${_currentSection + 1} ${_t("of")} $_totalSections",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
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
        return _buildAffiliationSection();
      case 6:
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
      _buildChoiceField(
        label: _t("physical_rehab_question"),
        keyName: "is_physical_rehabilitation",
        options: [_t("yes"), _t("no")],
      ),
    ];
  }

  List<Widget> _buildAffiliationSection() {
    return [
      _buildAffiliationFields(),
    ];
  }

  List<Widget> _buildHealthSettingsSection() {
    return [
      _buildChronicConditionsField(),
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

  Widget _buildAffiliationFields() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedAffiliationId =
        (_values["affiliation_id"]?.isNotEmpty ?? false) ? _values["affiliation_id"] : null;
    final affiliationChoice = _affiliationChoice;

    // Keep controller in sync with stored values
    if ((_values["affiliation_other_text"] ?? "").isNotEmpty &&
        _affiliationOtherCtrl.text != _values["affiliation_other_text"]) {
      _affiliationOtherCtrl.text = _values["affiliation_other_text"]!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChoiceField(
          label: _t("university_student_question"),
          keyName: "is_university_student",
          options: [_t("yes"), _t("no")],
        ),
        if (_isUniversityStudent == true) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true, //  FIX 1
            decoration: InputDecoration(
              labelText: _t("select_university"),
              border: const OutlineInputBorder(),
            ),
            initialValue: _selectedUniversityId,
            items: _universities
                .map(
                  (u) => DropdownMenuItem<String>(
                value: u["id"].toString(),
                child: Text(
                  u["name"],
                  overflow: TextOverflow.ellipsis, //  FIX 2
                ),
              ),
            )
                .toList(),
            validator: (val) {
              if (_isUniversityStudent == true && (val == null || val.isEmpty)) {
                return _t("select_option");
              }
              return null;
            },
            onChanged: _universitiesLoading
                ? null
                : (val) {
              setState(() {
                _selectedUniversityId = val;
                _values["university_id"] = val!;
              });
            },
          ),
        ],
        const SizedBox(height: 16),
        Divider(thickness: 1),
        const SizedBox(height: 16),
        Text(
          _t("affiliation_heading"),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey("affiliation_choice"),
          decoration: InputDecoration(
            labelText: _t("affiliation_prompt"),
            border: const OutlineInputBorder(),
          ),
          initialValue: affiliationChoice,
          items: [
            _t("yes"),
            _t("no"),
          ]
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(c),
                ),
              )
              .toList(),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return _t("select_option");
            }
            return null;
          },
          onChanged: (val) {
            setState(() {
              _saveField("affiliation_choice", val);
              if (val == _t("no")) {
                _values.remove("affiliation_id");
                _values.remove("affiliation_other_text");
                _affiliationOtherCtrl.clear();
                _affiliations = [];
                _selectedAffiliationCategory = null;
              }
            });
          },
          onSaved: (val) => _saveField("affiliation_choice", val),
        ),
        if (affiliationChoice == _t("yes")) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey("affiliation_category"),
            decoration: InputDecoration(
              labelText: _t("affiliation_category"),
              border: const OutlineInputBorder(),
            ),
            initialValue: _selectedAffiliationCategory,
            items: _affiliationCategories
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c,
                    child: Text(c),
                  ),
                )
                .toList(),
            validator: (val) {
              if (affiliationChoice == _t("yes") &&
                  (_affiliationOtherCtrl.text.trim().isEmpty) &&
                  (val == null || val.isEmpty)) {
                return _t("select_option");
              }
              return null;
            },
            onChanged: _affiliationCategories.isEmpty
                ? null
                : (val) {
                    setState(() {
                      _selectedAffiliationCategory = val;
                      _affiliations = [];
                      _values.remove("affiliation_id");
                      _affiliationError = null;
                    });
                    if (val != null && val.isNotEmpty) {
                      _loadAffiliationsForCategory(val);
                    }
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey("affiliation_id"),
            decoration: InputDecoration(
              labelText: _affiliationsLoading
                  ? _t("affiliation_loading")
                  : _t("affiliation_select"),
              border: const OutlineInputBorder(),
            ),
            initialValue: selectedAffiliationId,
            isExpanded: true,
            items: [
              ..._affiliations.map(
                    (item) => DropdownMenuItem<String>(
                  value: item["id"].toString(),
                  child: Text(item["name"]?.toString() ?? ""),
                ),
              ),
              DropdownMenuItem<String>(
                value: "custom",
                child: Text(_t("didnt_find_affiliation")),
              ),
            ],
            validator: (val) {
              if (affiliationChoice == _t("yes") &&
                  (_affiliationOtherCtrl.text.trim().isEmpty) &&
                  (val == null || val.isEmpty)) {
                return _t("select_option");
              }
              return null;
            },
            onChanged: _affiliations.isEmpty || _affiliationsLoading
                ? null
                : (val) {
              setState(() {
                if (val == "custom") {
                  _saveField("affiliation_id", "custom"); // ✅ IMPORTANT
                  _affiliationOtherCtrl.clear();
                } else {
                  _saveField("affiliation_id", val);
                  _affiliationOtherCtrl.clear();
                  _values.remove("affiliation_other_text");
                }

              });
            },
          ),if (_affiliationError != null) ...[
            const SizedBox(height: 6),
            Text(
              _affiliationError!,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ],

          if ((_values["affiliation_id"] ?? "") == "custom") ...[
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey("affiliation_other_text"),
              controller: _affiliationOtherCtrl,
              decoration: InputDecoration(
                labelText: _t("affiliation_other"),
                hintText: _t("affiliation_other_hint"),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) => _saveField("affiliation_other_text", val),
              validator: (val) {
                if ((_values["affiliation_id"] ?? "") == "custom" &&
                    (val == null || val.trim().isEmpty)) {
                  return _t("affiliation_required");
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Text(
              _t("affiliation_help"),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildChronicConditionsField() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final choice = _values["chronic_choice"];
    final yesLabel = _t("yes");
    final noLabel = _t("no");

    if ((_values["chronic_conditions"] ?? "").isNotEmpty &&
        choice == yesLabel &&
        _chronicCtrl.text != _values["chronic_conditions"]) {
      _chronicCtrl.text = _values["chronic_conditions"]!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey("chronic_choice"),
          decoration: InputDecoration(
            labelText: _t("chronic_prompt"),
            border: const OutlineInputBorder(),
          ),
          initialValue: choice,
          items: [
            DropdownMenuItem(value: yesLabel, child: Text(yesLabel)),
            DropdownMenuItem(value: noLabel, child: Text(noLabel)),
          ],
          validator: (val) {
            if (val == null || val.isEmpty) {
              return _t("select_option");
            }
            return null;
          },
          onChanged: (val) {
            setState(() {
              _saveField("chronic_choice", val);
              if (val == noLabel) {
                _chronicCtrl.clear();
                _saveField("chronic_conditions", "none");
              } else {
                _saveField("chronic_conditions", _chronicCtrl.text);
              }
            });
          },
          onSaved: (val) => _saveField("chronic_choice", val),
        ),
        if (choice == yesLabel) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey("chronic_conditions_text"),
            controller: _chronicCtrl,
            decoration: InputDecoration(
              labelText: _t("chronic_conditions"),
              border: const OutlineInputBorder(),
            ),
            onChanged: (val) => _saveField("chronic_conditions", val),
            onSaved: (val) => _saveField("chronic_conditions", val),
            validator: (val) {
              if (choice == yesLabel && (val == null || val.trim().isEmpty)) {
                return _t("required");
              }
              return null;
            },
          ),
        ] else ...[
        ],
      ],
    );
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
    final currentStored = _values[keyName];
    final otherLabel = _t("other");
    final hasOther = options.contains(otherLabel);
    final otherCtrl = _otherControllerFor(keyName);

    String? initialValue;
    if (options.contains(currentStored)) {
      initialValue = currentStored;
    } else if (hasOther && (currentStored?.isNotEmpty ?? false)) {
      initialValue = otherLabel;
      if (otherCtrl.text != currentStored) {
        otherCtrl.text = currentStored ?? "";
      }
    }

    final showOtherField = hasOther && initialValue == otherLabel;
    final isOtherSelected = showOtherField;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(keyName),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            initialValue: initialValue,
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
              if (value == otherLabel && otherCtrl.text.trim().isEmpty) {
                return _t("required");
              }
              return null;
            },
            onChanged: (val) {
              if (val != otherLabel) {
                otherCtrl.clear();
                _saveField(keyName, val);
              } else {
                _saveField(keyName, otherLabel);
              }
              setState(() {});
            },
            onSaved: (val) => _saveField(
              keyName,
              val == otherLabel ? otherCtrl.text : val,
            ),
          ),
          if (hasOther && (showOtherField || otherCtrl.text.isNotEmpty)) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: otherCtrl,
              decoration: InputDecoration(
                labelText: _t("other"),
                border: const OutlineInputBorder(),
              ),
              onChanged: (val) => _saveField(keyName, val),
              validator: (val) {
                if (isOtherSelected &&
                    val != null &&
                    val.trim().isEmpty) {
                  return _t("required");
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiChoiceField({
    required String label,
    required String keyName,
    required List<String> options,
  }) {
    final theme = Theme.of(context);
    final otherLabel = _t("other");
    final hasOther = options.contains(otherLabel);
    final otherCtrl = _otherControllerFor(keyName);

    return FormField<String>(
      key: ValueKey(keyName),
      initialValue: _values[keyName] ?? '',
      validator: (value) {
        final rawVal = value ?? '';
        final parts = rawVal.isNotEmpty ? rawVal.split(', ') : <String>[];
        if (parts.isEmpty) {
          return _t("select_one");
        }
        final hasCustom =
            parts.any((p) => !options.contains(p)) || parts.contains(otherLabel);
        if (hasCustom && otherCtrl.text.trim().isEmpty) {
          return _t("required");
        }
        return null;
      },
      onSaved: (value) => _saveField(keyName, value),
      builder: (state) {
        final raw = state.value ?? '';
        final selected = <String>{
          if (raw.isNotEmpty) ...raw.split(', '),
        };

        bool otherSelected = false;
        String? customOther;
        for (final s in selected) {
          if (!options.contains(s) || s == otherLabel) {
            otherSelected = true;
            if (!options.contains(s)) {
              customOther ??= s;
            }
          }
        }

        if (otherSelected && customOther != null && otherCtrl.text.isEmpty) {
          otherCtrl.text = customOther;
        }

        String composeValue() {
          final parts = <String>[];
          for (final o in options) {
            if (o == otherLabel) continue;
            if (selected.contains(o)) {
              parts.add(o);
            }
          }
          if (otherSelected) {
            parts.add(otherCtrl.text.isNotEmpty ? otherCtrl.text : otherLabel);
          }
          return parts.join(', ');
        }

        void updateValue() {
          state.didChange(composeValue());
        }

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
                  final isSelected = o == otherLabel ? otherSelected : selected.contains(o);
                  return FilterChip(
                    label: Text(o),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        if (o == otherLabel) {
                          otherSelected = value;
                          if (!value) {
                            otherCtrl.clear();
                          }
                        } else {
                          if (value) {
                            selected.add(o);
                          } else {
                            selected.remove(o);
                          }
                        }
                        updateValue();
                      });
                    },
                  );
                }).toList(),
              ),
              if (hasOther && (otherSelected || otherCtrl.text.isNotEmpty)) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: otherCtrl,
                  decoration: InputDecoration(
                    labelText: _t("other"),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => updateValue(),
                ),
              ],
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
