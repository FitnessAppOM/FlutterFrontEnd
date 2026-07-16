import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../localization/app_localizations.dart';
import 'cupertino_picker_field.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/components/taqa_underline_field.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../services/auth/affiliation_service.dart';
import '../../services/core/university_service.dart';

class QuestionnaireForm extends StatefulWidget {
  const QuestionnaireForm({super.key, this.onSubmit});

  final void Function(Map<String, String>)? onSubmit;

  @override
  State<QuestionnaireForm> createState() => _QuestionnaireFormState();
}

class _QuestionnaireFormState extends State<QuestionnaireForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _values = {};
  final Map<String, TextEditingController> _otherControllers = {};
  int _currentSection = 0;
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  void _saveField(String key, String? value) {
    if (value == null || value.trim().isEmpty) {
      _values.remove(key);
      return;
    }
    _values[key] = value.trim();

    if (key == "is_physical_rehabilitation") {
      final yes = _t("yes");

      setState(() {
        _isPhysicalRehab = value == yes;

        if (_isPhysicalRehab == false) {
          _values.remove("physical_rehab_area");
        }
      });

      _loadAffiliationCategories();
    }
    if (key == "is_university_student") {
      final yes = _t("yes");

      setState(() {
        _isUniversityStudent = value == yes;

        if (_isUniversityStudent == false) {
          _selectedUniversityId = null;
          _values["university_id"] =
              "0"; // backend requires this field even when not a student
        }
      });

      if (_isUniversityStudent == true) {
        _loadUniversities();
      }
    }
    if (key == "event_deadline" && value == _t("no")) {
      _values.remove("deadline_date");
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
        _affiliations = items
            .where((item) => !_isOther(item["name"]?.toString() ?? ""))
            .toList();
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

    // Backend expects university_id even when not a student (use 0)
    _values["university_id"] = _values["university_id"] ?? "0";

    // Both muscle priorities are required by the questionnaire API.
    if (_currentSection == 1) {
      final hasUpper = (_values["muscle_priority_upper"] ?? "").isNotEmpty;
      final hasLower = (_values["muscle_priority_lower"] ?? "").isNotEmpty;
      if (!hasUpper || !hasLower) {
        if (!mounted) return;
        AppToast.show(
          context,
          "Please select both upper and lower muscle priorities.",
          type: AppToastType.error,
        );
        return;
      }
      final deadlineIsYes = (_values["event_deadline"] ?? "") == _t("yes");
      final deadlineDate = (_values["deadline_date"] ?? "").trim();
      if (deadlineIsYes && deadlineDate.isEmpty) {
        if (!mounted) return;
        AppToast.show(
          context,
          _t("deadline_date_required"),
          type: AppToastType.error,
        );
        return;
      }
    }

    if (_currentSection < _totalSections - 1) {
      setState(() {
        _currentSection++;
      });
      _scrollToTop();
    } else {
      await _submit();
    }
  }

  void _back() {
    if (_currentSection > 0) {
      setState(() {
        _currentSection--;
      });
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
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
    final cleanedValues = Map<String, String>.from(_values);
    // UI-only fields/removed questions: do not send to backend.
    cleanedValues.remove("consent");
    cleanedValues.remove("auto_recovery");
    cleanedValues.remove("meal_plan");
    cleanedValues.remove("physical_rehab_area");

    // Keep backend payload stable while showing richer labels on UI.
    cleanedValues["time_to_change"] = _canonicalTimeToChange(
      cleanedValues["time_to_change"] ?? "",
    );
    cleanedValues["sleep_hours"] = _canonicalSleepHours(
      cleanedValues["sleep_hours"] ?? "",
    );
    final deadlineDate = (cleanedValues["deadline_date"] ?? "").trim();
    if (deadlineDate.isNotEmpty) {
      // Always prioritize selected date text in backend field.
      cleanedValues["event_deadline"] = deadlineDate;
    } else if (_norm(cleanedValues["event_deadline"] ?? "") ==
        _norm(_t("no"))) {
      cleanedValues["event_deadline"] = "no";
    }
    // Avoid sending extra field unless backend explicitly adds it.
    cleanedValues.remove("deadline_date");
    final isStudentRaw = (cleanedValues["is_university_student"] ?? "")
        .trim()
        .toLowerCase();
    final isStudent =
        isStudentRaw == "yes" || isStudentRaw == _t("yes").toLowerCase();
    cleanedValues["is_university_student"] = isStudent ? "true" : "false";
    if (!isStudent) {
      cleanedValues["university_id"] = "0";
    }

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
      "main_goal": ["lose_weight", "gain_weight", "maintain_weight"],
      "motivation": [
        "look_better",
        "feel_stronger",
        "health_better",
        "more_energy",
        "mental_wellbeing",
      ],
      "muscle_priority_upper": ["chest", "back", "shoulders"],
      "muscle_priority_lower": ["quads", "hamstrings", "glutes"],
      "time_to_change": ["4", "8", "12", "no_timeframe"],
      "body_type": ["slender", "average", "heavy"],
      "fitness_experience": ["beginner", "intermediate", "advanced"],
      "training_days": ["1", "2", "3", "4", "5", "6"],
      "preferred_time": ["morning", "noon", "afternoon", "evening", "flexible"],
      "training_location": ["gym", "home", "hybrid"],
      "train_mode": ["alone", "partner", "trainer"],
      "is_university_student": ["yes", "no"],
      "is_physical_rehabilitation": ["yes", "no"],
      "meals_per_day": ["2", "3", "4", "5", "6"],
      "food_habit": ["cook", "eat_out", "mix"],
      "kitchen_access": ["yes", "no"],
      "water_intake": ["<1l", "1–2l", "2–3l", ">3l"],
      "daily_activity": ["sedentary", "moderate", "active", "highly_active"],
      "sleep_hours": ["<6", "6–7", "7–8", ">8"],
      "sleep_consistency": ["regular", "irregular"],
      "wake_feeling": ["tired", "okay", "refreshed"],
      "stress_level": ["low", "moderate", "high"],
    };

    const multiChoiceOptions = {
      "past_injuries": [
        "shoulder",
        "back",
        "knee",
        "elbow",
        "foot_ankle",
        "arm_wrist",
        "none",
      ],
      "allergies": ["dairy", "gluten", "nuts", "shellfish", "none", "other"],
      "supplements": ["protein", "creatine", "multivitamin", "none", "other"],
      "diet_type": [
        "no_pref",
        "high_protein",
        "low_carb",
        "vegetarian",
        "vegan",
      ],
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

  String _canonicalTimeToChange(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    if (_norm(v) == _norm(_t("no_timeframe"))) {
      return "no_timeframe";
    }
    if (v.startsWith("4")) return "4";
    if (v.startsWith("8")) return "8";
    if (v.startsWith("12")) return "12";
    return v;
  }

  String _canonicalSleepHours(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    if (v.startsWith("<6")) return "<6";
    if (v.startsWith("6")) return "6–7";
    if (v.startsWith("7")) return "7–8";
    if (v.startsWith(">8")) return ">8";
    return v;
  }

  TextEditingController _otherControllerFor(String key) {
    return _otherControllers.putIfAbsent(key, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    // Layout: the question fields scroll inside Expanded, while the Back/Next
    // bar is pinned at the bottom (outside the scroll view). This guarantees the
    // navigation buttons stay reachable on every screen size, font/display scale,
    // and when the keyboard is open — on both iOS and Android. Previously the
    // buttons lived at the end of the scroll content and could fall off-screen.
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepProgressBar(current: _currentSection, total: _totalSections),
          SizedBox(height: TaqaUiScale.h(16)),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sectionTitle,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(20),
                      fontWeight: FontWeight.w700,
                      height: 26 / 20,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(4)),
                  Text(
                    _sectionSubtitle,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w400,
                      height: 18 / 13,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(20)),
                  ..._buildCurrentSectionFields(),
                ],
              ),
            ),
          ),
          // Pinned navigation bar — always visible at the bottom.
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(top: TaqaUiScale.h(12)),
              child: Row(
                children: [
                  if (_currentSection > 0)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _back,
                          child: SizedBox(
                            height: TaqaUiScale.h(48),
                            child: Center(
                              child: Text(
                                _t("back").toUpperCase(),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(11),
                                  fontWeight: FontWeight.w700,
                                  color: TaqaUiColors.unnamedColor1c1d17
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_currentSection > 0) SizedBox(width: TaqaUiScale.w(12)),
                  Expanded(
                    child: TaqaFilledButton(
                      label: _currentSection == _totalSections - 1
                          ? _t("finish")
                          : _t("next"),
                      onTap: _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      _buildTextField(
        label: "${_t("height")} (cm)",
        keyName: "height_cm",
        keyboardType: TextInputType.number,
        minValue: 120,
        maxValue: 240,
      ),
      _buildTextField(
        label: "${_t("weight")} (kg)",
        keyName: "weight_kg",
        keyboardType: TextInputType.number,
        minValue: 35,
        maxValue: 300,
      ),
    ];
  }

  List<Widget> _buildGoalsSection() {
    return [
      _buildChoiceField(
        label: _t("goal_main"),
        keyName: "main_goal",
        options: [_t("lose_weight"), _t("gain_weight"), _t("maintain_weight")],
        subtitle: _t("goal_main_subtitle"),
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
        label: _t("muscle_priority_upper"),
        keyName: "muscle_priority_upper",
        options: [_t("chest"), _t("back_muscle"), _t("shoulders")],
      ),
      _buildChoiceField(
        label: _t("muscle_priority_lower"),
        keyName: "muscle_priority_lower",
        options: [_t("quads"), _t("hamstrings"), _t("glutes")],
      ),
      _buildChoiceField(
        label: _t("time_change"),
        keyName: "time_to_change",
        options: [
          _t("time_4_weeks"),
          _t("time_8_weeks"),
          _t("time_12_weeks"),
          _t("no_timeframe"),
        ],
      ),
      _buildChoiceField(
        label: _t("deadline"),
        keyName: "event_deadline",
        options: [_t("yes"), _t("no")],
      ),
      if ((_values["event_deadline"] ?? "") == _t("yes")) ...[
        TaqaUnderlineTextField(
          controller: _otherControllerFor("deadline_date_display")
            ..text = (_values["deadline_date"] ?? "").isNotEmpty
                ? _values["deadline_date"]!
                : "",
          label: _t("deadline_date"),
          hint: _t("select_date"),
          readOnly: true,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 3650)),
            );
            if (picked != null) {
              final formatted =
                  "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              setState(() => _values["deadline_date"] = formatted);
            }
          },
        ),
        SizedBox(height: TaqaUiScale.h(12)),
      ],
    ];
  }

  List<Widget> _buildTrainingSection() {
    return [
      _buildChoiceField(
        label: _t("body_type"),
        keyName: "body_type",
        options: [_t("slender"), _t("average"), _t("heavy")],
      ),
      _buildChoiceField(
        label: _t("fitness_experience"),
        keyName: "fitness_experience",
        options: [_t("beginner"), _t("intermediate"), _t("advanced")],
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
      _buildMultiChoiceField(
        label: _t("past_injuries"),
        keyName: "past_injuries",
        options: [
          _t("shoulder"),
          _t("back"),
          _t("knee"),
          _t("elbow"),
          _t("foot_ankle"),
          _t("arm_wrist"),
          _t("none"),
        ],
      ),
      _buildChoiceField(
        label: _t("train_mode"),
        keyName: "train_mode",
        options: [_t("alone"), _t("partner"), _t("trainer")],
      ),
    ];
  }

  List<Widget> _buildNutritionSection() {
    return [
      Text(
        _t("questionnaire_nutrition_intro"),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
      const SizedBox(height: 8),
      _buildMultiChoiceField(
        label: _t("diet_type"),
        keyName: "diet_type",
        options: [
          _t("no_pref"),
          _t("high_protein"),
          _t("low_carb"),
          _t("vegetarian"),
          _t("vegan"),
        ],
        requiredField: false,
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
    ];
  }

  List<Widget> _buildLifestyleSection() {
    return [
      _buildChoiceField(
        label: _t("daily_activity"),
        keyName: "daily_activity",
        options: [
          _t("sedentary"),
          _t("moderate"),
          _t("active"),
          _t("highly_active"),
        ],
      ),
      _buildChoiceField(
        label: _t("sleep_hours"),
        keyName: "sleep_hours",
        options: [
          _t("sleep_lt6_hours"),
          _t("sleep_6_7_hours"),
          _t("sleep_7_8_hours"),
          _t("sleep_gt8_hours"),
        ],
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
      if (_isPhysicalRehab == true)
        _buildChoiceField(
          label: _t("physical_rehab_area_question"),
          keyName: "physical_rehab_area",
          options: [
            _t("shoulder"),
            _t("back_muscle"),
            _t("chest"),
            _t("rehab_arms"),
            _t("knee"),
            _t("rehab_ankle_foot"),
          ],
        ),
    ];
  }

  List<Widget> _buildAffiliationSection() {
    return [_buildAffiliationFields()];
  }

  List<Widget> _buildHealthSettingsSection() {
    return [_buildChronicConditionsField()];
  }

  Widget _buildAffiliationFields() {
    final selectedAffiliationId =
        (_values["affiliation_id"]?.isNotEmpty ?? false)
        ? _values["affiliation_id"]
        : null;
    final affiliationChoice = _affiliationChoice;

    // Keep controller in sync with stored values
    if ((_values["affiliation_other_text"] ?? "").isNotEmpty &&
        _affiliationOtherCtrl.text != _values["affiliation_other_text"]) {
      _affiliationOtherCtrl.text = _values["affiliation_other_text"]!;
    }

    final universityIdToName = {
      for (final u in _universities) u["id"].toString(): u["name"].toString(),
    };
    final affiliationIdToName = {
      for (final item in _affiliations)
        item["id"].toString(): item["name"]?.toString() ?? "",
      "custom": _t("didnt_find_affiliation"),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChoiceField(
          label: _t("university_student_question"),
          keyName: "is_university_student",
          options: [_t("yes"), _t("no")],
        ),
        if (_isUniversityStudent == true) ...[
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaUnderlineDropdown(
            label: _t("select_university"),
            value: _selectedUniversityId,
            options: universityIdToName.keys.toList(),
            itemLabelBuilder: (id) => universityIdToName[id] ?? id,
            validator: (val) {
              if (_isUniversityStudent == true &&
                  (val == null || val.isEmpty)) {
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
        SizedBox(height: TaqaUiScale.h(16)),
        TaqaSectionDivider(),
        Text(
          _t("affiliation_heading"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(8)),
        TaqaUnderlineDropdown(
          label: _t("affiliation_prompt"),
          value: affiliationChoice,
          options: [_t("yes"), _t("no")],
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
        ),
        if (affiliationChoice == _t("yes")) ...[
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaUnderlineDropdown(
            label: _t("affiliation_category"),
            value: _selectedAffiliationCategory,
            options: _affiliationCategories,
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
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaUnderlineDropdown(
            label: _affiliationsLoading
                ? _t("affiliation_loading")
                : _t("affiliation_select"),
            value: selectedAffiliationId,
            options: affiliationIdToName.keys.toList(),
            itemLabelBuilder: (id) => affiliationIdToName[id] ?? id,
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
          ),
          if (_affiliationError != null) ...[
            SizedBox(height: TaqaUiScale.h(6)),
            Text(
              _affiliationError!,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(12),
                color: TaqaUiColors.unnamedColorE93b3b,
              ),
            ),
          ],

          if ((_values["affiliation_id"] ?? "") == "custom") ...[
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaUnderlineTextField(
              controller: _affiliationOtherCtrl,
              label: _t("affiliation_other"),
              hint: _t("affiliation_other_hint"),
              onChanged: (val) => _saveField("affiliation_other_text", val),
              validator: (val) {
                if ((_values["affiliation_id"] ?? "") == "custom" &&
                    (val == null || val.trim().isEmpty)) {
                  return _t("affiliation_required");
                }
                return null;
              },
            ),
            SizedBox(height: TaqaUiScale.h(6)),
            Text(
              _t("affiliation_help"),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(11),
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
              ),
            ),
          ],

          SizedBox(height: TaqaUiScale.h(16)),
        ],
      ],
    );
  }

  Widget _buildChronicConditionsField() {
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
        TaqaUnderlineDropdown(
          key: const ValueKey("chronic_choice"),
          label: _t("chronic_prompt"),
          value: choice,
          options: [yesLabel, noLabel],
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
        ),
        if (choice == yesLabel) ...[
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaUnderlineTextField(
            key: const ValueKey("chronic_conditions_text"),
            controller: _chronicCtrl,
            label: _t("chronic_conditions"),
            onChanged: (val) => _saveField("chronic_conditions", val),
            validator: (val) {
              if (choice == yesLabel && (val == null || val.trim().isEmpty)) {
                return _t("required");
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String keyName,
    TextInputType? keyboardType,
    int? minValue,
    int? maxValue,
  }) {
    final ctrl = _otherControllerFor(keyName);
    if (ctrl.text != (_values[keyName] ?? "")) {
      ctrl.text = _values[keyName] ?? "";
    }
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: TaqaUnderlineTextField(
        key: ValueKey(keyName),
        controller: ctrl,
        label: label,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return _t("required");
          }
          if (keyboardType == TextInputType.number) {
            final parsed = int.tryParse(value.trim());
            if (parsed == null) {
              return _t("invalid_number");
            }
            if (minValue != null && parsed < minValue) {
              return "Min $minValue";
            }
            if (maxValue != null && parsed > maxValue) {
              return "Max $maxValue";
            }
          }
          return null;
        },
        onChanged: (val) => _saveField(keyName, val),
      ),
    );
  }

  Widget _buildChoiceField({
    required String label,
    required String keyName,
    required List<String> options,
    bool requiredField = true,
    String? subtitle,
  }) {
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

    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            softWrap: true,
            maxLines: null,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w600,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: TaqaUiScale.h(4)),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(11),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
              ),
            ),
          ],
          SizedBox(height: TaqaUiScale.h(8)),
          FormField<String?>(
            key: ValueKey(keyName),
            initialValue: initialValue,
            validator: (value) {
              if (!requiredField && (value == null || value.isEmpty)) {
                return null;
              }
              if (value == null || value.isEmpty) {
                return _t("select_option");
              }
              if (value == otherLabel && otherCtrl.text.trim().isEmpty) {
                return _t("required");
              }
              return null;
            },
            onSaved: (val) => _saveField(
              keyName,
              val == null || val.isEmpty
                  ? null
                  : val == otherLabel
                  ? otherCtrl.text
                  : val,
            ),
            builder: (state) {
              final value = state.value;
              final showOtherField = hasOther && value == otherLabel;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: TaqaUiScale.w(10),
                    runSpacing: TaqaUiScale.h(10),
                    children: options.map((o) {
                      return TaqaPillChoice(
                        label: o,
                        selected: value == o,
                        onTap: () {
                          setState(() {
                            if (o != otherLabel) {
                              otherCtrl.clear();
                              _saveField(keyName, o);
                            } else {
                              _saveField(keyName, otherLabel);
                            }
                            state.didChange(o);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (showOtherField) ...[
                    SizedBox(height: TaqaUiScale.h(8)),
                    TaqaUnderlineTextField(
                      controller: otherCtrl,
                      label: _t("other"),
                      onChanged: (val) => _saveField(keyName, val),
                      validator: (val) {
                        if (showOtherField &&
                            val != null &&
                            val.trim().isEmpty) {
                          return _t("required");
                        }
                        return null;
                      },
                    ),
                  ],
                  if (state.hasError) ...[
                    SizedBox(height: TaqaUiScale.h(4)),
                    TaqaRequiredHint(text: state.errorText ?? ''),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultiChoiceField({
    required String label,
    required String keyName,
    required List<String> options,
    bool requiredField = true,
  }) {
    final otherLabel = _t("other");
    final hasOther = options.contains(otherLabel);
    final otherCtrl = _otherControllerFor(keyName);

    return FormField<String>(
      key: ValueKey(keyName),
      initialValue: _values[keyName] ?? '',
      validator: (value) {
        final rawVal = value ?? '';
        final parts = rawVal.isNotEmpty ? rawVal.split(', ') : <String>[];
        if (!requiredField && parts.isEmpty) {
          return null;
        }
        if (parts.isEmpty) {
          return _t("select_one");
        }
        final hasCustom =
            parts.any((p) => !options.contains(p)) ||
            parts.contains(otherLabel);
        if (hasCustom && otherCtrl.text.trim().isEmpty) {
          return _t("required");
        }
        return null;
      },
      onSaved: (value) => _saveField(keyName, value),
      builder: (state) {
        final raw = state.value ?? '';
        final selected = <String>{if (raw.isNotEmpty) ...raw.split(', ')};

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
          padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(13),
                  fontWeight: FontWeight.w600,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(8)),
              Wrap(
                spacing: TaqaUiScale.w(10),
                runSpacing: TaqaUiScale.h(10),
                children: options.map((o) {
                  final isSelected = o == otherLabel
                      ? otherSelected
                      : selected.contains(o);
                  return TaqaPillChoice(
                    label: o,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        final value = !isSelected;
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
                SizedBox(height: TaqaUiScale.h(8)),
                TaqaUnderlineTextField(
                  controller: otherCtrl,
                  label: _t("other"),
                  onChanged: (_) => updateValue(),
                ),
              ],
              if (state.hasError) TaqaRequiredHint(text: state.errorText ?? ''),
            ],
          ),
        );
      },
    );
  }
}

/// Segmented progress bar showing which step of the wizard the user is on.
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i <= current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i == total - 1 ? 0 : TaqaUiScale.w(6),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: TaqaUiScale.h(4),
              decoration: BoxDecoration(
                color: filled
                    ? TaqaUiColors.unnamedColorE4e93b
                    : TaqaUiColors.unnamedColorE3e3e3,
                borderRadius: TaqaUiScale.radius(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}
