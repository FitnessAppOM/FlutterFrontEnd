import 'package:flutter/material.dart';

import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/profile_service.dart';
import '../../services/affiliation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/primary_button.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _trainingStyleCtrl = TextEditingController();
  final _pastInjuriesCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();
  final _dietOtherCtrl = TextEditingController();
  String? _affiliationId;
  String? _affiliationOther;
  String? _affiliationName;

  String? _sex;
  String? _mainGoal;
  String? _trainingDays;
  String? _fitnessExperience;
  String? _dailyActivity;
  String? _dietType;
  String? _trainingStyle;
  String? _chronicChoice;

  bool _saving = false;
  bool _hasValidationError = false;

  late final Map<String, dynamic> _initial;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _initial = Map<String, dynamic>.from(widget.profile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _prefill();
    _didInit = true;
    setState(() {});
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _trainingStyleCtrl.dispose();
    _pastInjuriesCtrl.dispose();
    _chronicCtrl.dispose();
    _dietOtherCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    final p = widget.profile;
    _ageCtrl.text = _str(p["age"]);
    _heightCtrl.text = _str(p["height_cm"]);
    _weightCtrl.text = _str(p["weight_kg"]);
    _pastInjuriesCtrl.text = _str(p["previous_injuries"]);

    _sex = _mapOptionKey(_str(p["sex"]), _sexOptions());
    _mainGoal = _mapOptionKey(_str(p["fitness_goal"]), _goalOptions());
    _trainingDays = _matchOption(p["training_days"], _trainingDaysOptions());
    _fitnessExperience =
        _mapOptionKey(_str(p["fitness_experience"]), _fitnessExperienceOptions()) ??
            _matchOption(p["fitness_experience"], _fitnessExperienceOptions());
    _dailyActivity = _mapOptionKey(_str(p["occupation"]), _dailyActivityOptions());

    final dietRaw = _str(p["diet_type"]);
    final matchedDiet = _mapOptionKey(dietRaw, _dietOptions());
    if (matchedDiet == null && dietRaw.isNotEmpty) {
      _dietType = _otherKey;
      _dietOtherCtrl.text = dietRaw;
    } else {
      _dietType = matchedDiet;
    }

    final trainingRaw = _str(p["training_style"]);
    final matchedTraining = _mapOptionKey(trainingRaw, _trainingStyleOptions());
    if (matchedTraining == null && trainingRaw.isNotEmpty) {
      _trainingStyle = _otherKey;
      _trainingStyleCtrl.text = trainingRaw;
    } else {
      _trainingStyle = matchedTraining;
    }

    final chronicRaw = _str(p["pain"]);
    if (chronicRaw.isEmpty || _isNone(chronicRaw)) {
      _chronicChoice = null;
      _chronicCtrl.clear();
    } else {
      _chronicChoice = _t("yes");
      _chronicCtrl.text = chronicRaw;
    }

    _affiliationId = _str(p["affiliation_id"]);
    _affiliationOther = _str(p["affiliation_other_text"]);
    _affiliationName = _str(p["affiliation_name"]);
  }

  String _t(String key) => AppLocalizations.of(context).translate(key);

  String _str(dynamic v) => v?.toString().trim() ?? "";

  String get _otherKey => "other";
  String get _otherLabel => _t("other");

  List<String> _sexOptions() => ["male", "female", "prefer_not"];
  List<String> _goalOptions() => [
        "lose_weight",
        "gain_muscle",
        "improve_endurance",
        "maintain_fitness",
        "improve_health",
      ];
  List<String> _trainingDaysOptions() =>
      List<String>.generate(7, (i) => "${i + 1}");
  List<String> _fitnessExperienceOptions() =>
      ["beginner", "intermediate", "advanced"];
  List<String> _dailyActivityOptions() =>
      ["sedentary", "moderate", "active", "highly_active"];
  List<String> _dietOptions() => [
        "no_pref",
        "high_protein",
        "low_carb",
        "vegetarian",
        "vegan",
        "fasting",
        _otherKey,
      ];
  List<String> _trainingStyleOptions() => [
        "strength",
        "hypertrophy",
        "functional",
        "endurance",
        "hiit",
        "mobility",
        _otherKey,
      ];

  String _norm(String v) =>
      v.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').replaceAll('–', ' ').trim();

  String? _mapOptionKey(String raw, List<String> keys) {
    final normalized = _norm(raw);
    for (final key in keys) {
      if (normalized == _norm(key) || normalized == _norm(_t(key))) {
        return key;
      }
    }
    return null;
  }

  String? _matchOption(dynamic raw, List<String> options) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    for (final o in options) {
      if (o.toLowerCase() == value) return o;
    }
    return null;
  }

  bool _isNone(String value) {
    final v = value.trim().toLowerCase();
    return v == "none" || v == _t("chronic_none_value").toLowerCase();
  }

  Future<void> _submit() async {
    _formKey.currentState!.save();
    _hasValidationError = false;

    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      if (!mounted) return;
      AppToast.show(context, _t("user_missing"), type: AppToastType.error);
      return;
    }

    final payload = <String, dynamic>{"user_id": userId};

    int? parseInt(String label, String value, {String? fallback}) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        if (fallback == null || fallback.isEmpty) return null;
        return int.tryParse(fallback);
      }
      final parsed = int.tryParse(trimmed);
      if (parsed == null) {
        _hasValidationError = true;
        AppToast.show(context, "$label: ${_t("invalid_number")}",
            type: AppToastType.error);
      }
      return parsed;
    }

    String initialStr(String key) => _str(_initial[key]);

    final ageVal = parseInt(_t("age"), _ageCtrl.text, fallback: initialStr("age"));
    final heightVal = parseInt(_t("height"), _heightCtrl.text, fallback: initialStr("height_cm"));
    final weightVal = parseInt(_t("weight"), _weightCtrl.text, fallback: initialStr("weight_kg"));

    final mainGoalKey =
        _mainGoal ?? _mapOptionKey(initialStr("fitness_goal"), _goalOptions()) ?? "";
    final trainingDaysKey =
        _trainingDays ?? _mapOptionKey(initialStr("training_days"), _trainingDaysOptions()) ?? "";
    final fitnessExpKey = _fitnessExperience ??
        _mapOptionKey(initialStr("fitness_experience"), _fitnessExperienceOptions()) ??
        "";
    final activityKey =
        _dailyActivity ?? _mapOptionKey(initialStr("occupation"), _dailyActivityOptions()) ?? "";

    String? resolvedDietKey = _dietType ?? _mapOptionKey(initialStr("diet_type"), _dietOptions());
    if (resolvedDietKey == null && _dietOtherCtrl.text.trim().isEmpty) {
      resolvedDietKey = initialStr("diet_type").isNotEmpty ? _otherKey : null;
    }
    String? resolvedTrainingKey =
        _trainingStyle ?? _mapOptionKey(initialStr("training_style"), _trainingStyleOptions());
    if (resolvedTrainingKey == null && _trainingStyleCtrl.text.trim().isEmpty) {
      resolvedTrainingKey = initialStr("training_style").isNotEmpty ? _otherKey : null;
    }

    final pastInjuriesVal = _pastInjuriesCtrl.text.trim().isNotEmpty
        ? _pastInjuriesCtrl.text.trim()
        : initialStr("previous_injuries");

    final chronicValueRaw = _chronicChoice == _t("no")
        ? "none"
        : (_chronicCtrl.text.trim().isNotEmpty
            ? _chronicCtrl.text.trim()
            : initialStr("pain"));
    final chronicValue = _isNone(chronicValueRaw) ? "none" : chronicValueRaw;

    if (_hasValidationError) return;

    final sexVal = (_sex ?? _mapOptionKey(initialStr("sex"), _sexOptions()) ?? "").trim();
    payload.addAll({
      "age": ageVal,
      "sex": sexVal.isEmpty ? null : sexVal,
      "height_cm": heightVal,
      "weight_kg": weightVal,
      "main_goal": mainGoalKey.isEmpty ? null : mainGoalKey,
      "training_days": trainingDaysKey.isEmpty ? null : trainingDaysKey,
      "fitness_experience": fitnessExpKey.isEmpty ? null : fitnessExpKey,
      "daily_activity": activityKey.isEmpty ? null : activityKey,
      "diet_type": resolvedDietKey == _otherKey ? _dietOtherCtrl.text.trim() : resolvedDietKey,
      "training_style":
          resolvedTrainingKey == _otherKey ? _trainingStyleCtrl.text.trim() : resolvedTrainingKey,
      "past_injuries": pastInjuriesVal,
      "chronic_conditions": chronicValue,
    });

    final affIdStr = _affiliationId?.trim() ?? "";
    final affOtherStr = _affiliationOther?.trim() ?? "";
    payload["affiliation_id"] = affIdStr.isEmpty ? null : int.tryParse(affIdStr);
    payload["affiliation_other_text"] = affOtherStr;

    setState(() => _saving = true);
    try {
      await ProfileApi.updateProfile(payload);
      if (!mounted) return;
      AppToast.show(
        context,
        _t("profile_update_success"),
        type: AppToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${_t("profile_update_failed")}: $e",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text(t.translate("edit_profile")),
        backgroundColor: AppColors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(t.translate("section_basics_title")),
              Row(
                children: [
                  Expanded(child: _numberField(_ageCtrl, t.translate("age"))),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField(_heightCtrl, t.translate("height"))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numberField(_weightCtrl, t.translate("weight"))),
                  const SizedBox(width: 12),
                  Expanded(child: _dropdownField(
                    label: t.translate("sex"),
                    value: _sex,
                    options: _sexOptions(),
                    translateOptions: true,
                    onChanged: (v) => setState(() => _sex = v),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              _sectionTitle(t.translate("affiliation")),
              _affiliationBlock(),
              const SizedBox(height: 20),
              _sectionTitle(t.translate("section_goals_title")),
              _dropdownField(
                label: t.translate("goal_main"),
                value: _mainGoal,
                options: _goalOptions(),
                translateOptions: true,
                onChanged: (v) => setState(() => _mainGoal = v),
              ),
              _dropdownField(
                label: t.translate("training_days"),
                value: _trainingDays,
                options: _trainingDaysOptions(),
                onChanged: (v) => setState(() => _trainingDays = v),
              ),
              _dropdownField(
                label: t.translate("fitness_experience"),
                value: _fitnessExperience,
                options: _fitnessExperienceOptions(),
                translateOptions: true,
                onChanged: (v) => setState(() => _fitnessExperience = v),
              ),
              _dropdownField(
                label: t.translate("daily_activity"),
                value: _dailyActivity,
                options: _dailyActivityOptions(),
                translateOptions: true,
                onChanged: (v) => setState(() => _dailyActivity = v),
              ),
              const SizedBox(height: 12),
              _sectionTitle(t.translate("section_nutrition_title")),
              _dropdownField(
                label: t.translate("diet_type"),
                value: _dietType,
                options: _dietOptions(),
                translateOptions: true,
                onChanged: (v) {
                  setState(() {
                    _dietType = v;
                    if (v != _otherKey) {
                      _dietOtherCtrl.clear();
                    }
                  });
                },
              ),
              if (_dietType == _otherKey)
                _textField(_dietOtherCtrl, t.translate("other")),
              const SizedBox(height: 12),
              _sectionTitle(t.translate("section_training_title")),
              _dropdownField(
                label: t.translate("training_style"),
                value: _trainingStyle,
                options: _trainingStyleOptions(),
                translateOptions: true,
                onChanged: (v) {
                  setState(() {
                    _trainingStyle = v;
                    if (v != _otherKey) _trainingStyleCtrl.clear();
                  });
                },
              ),
              if (_trainingStyle == _otherKey)
                _textField(_trainingStyleCtrl, t.translate("other")),
              _textField(
                _pastInjuriesCtrl,
                t.translate("past_injuries"),
                hint: t.translate("past_injuries"),
                required: false,
              ),
              const SizedBox(height: 12),
              _sectionTitle(t.translate("sec_health_title")),
              _chronicChoiceField(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PrimaryWhiteButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t.translate("save")),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.greyDark),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(t.translate("cancel")),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _affiliationBlock() {
    final t = AppLocalizations.of(context);
    final subtitle = (_affiliationName != null && _affiliationName!.isNotEmpty)
        ? _affiliationName!
        : (_affiliationOther != null && _affiliationOther!.isNotEmpty)
            ? _affiliationOther!
            : t.translate("not_set");

    return Card(
      color: AppColors.greyDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.translate("affiliation"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<Map<String, String?>>(
                  MaterialPageRoute(
                    builder: (_) => _AffiliationSelectionPage(
                      initialId: _affiliationId,
                      initialOther: _affiliationOther,
                      initialName: _affiliationName,
                    ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _affiliationId = result["id"];
                    _affiliationName = result["name"] ?? "";
                    _affiliationOther = result["other"] ?? "";
                    if ((_affiliationId ?? "").isNotEmpty) {
                      _affiliationOther = "";
                    }
                    if ((_affiliationOther ?? "").isNotEmpty) {
                      _affiliationId = null;
                      _affiliationName = "";
                    }
                  });
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.accent),
              ),
              child: Text(t.translate("set")),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return _textField(
      controller,
      label,
      keyboardType: TextInputType.number,
      requireNumber: true,
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? hint,
    bool required = false,
    bool requireNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(color: Colors.white),
        validator: (val) {
          if (requireNumber && val != null && val.trim().isNotEmpty) {
            if (int.tryParse(val.trim()) == null) {
              return _t("invalid_number");
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool translateOptions = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: value,
        style: const TextStyle(color: Colors.white),
        dropdownColor: AppColors.black,
        items: options
            .map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(translateOptions ? _t(o) : o),
                ))
            .toList(),
        validator: (_) => null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _chronicChoiceField() {
    final yes = _t("yes");
    final no = _t("no");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: _t("chronic_prompt"),
            border: const OutlineInputBorder(),
          ),
          value: _chronicChoice,
          style: const TextStyle(color: Colors.white),
          dropdownColor: AppColors.black,
          items: [
            DropdownMenuItem(value: yes, child: Text(yes)),
            DropdownMenuItem(value: no, child: Text(no)),
          ],
          validator: (val) {
            if (val == null || val.isEmpty) {
              return _t("select_option");
            }
            return null;
          },
          onChanged: (val) {
            setState(() {
              _chronicChoice = val;
              if (val == no) {
                _chronicCtrl.clear();
              }
            });
          },
        ),
        if (_chronicChoice == yes)
          _textField(
            _chronicCtrl,
            _t("chronic_conditions"),
          ),
      ],
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg, type: AppToastType.error);
  }
}

class _AffiliationSelectionPage extends StatefulWidget {
  const _AffiliationSelectionPage({
    required this.initialId,
    required this.initialOther,
    required this.initialName,
  });

  final String? initialId;
  final String? initialOther;
  final String? initialName;

  @override
  State<_AffiliationSelectionPage> createState() => _AffiliationSelectionPageState();
}

class _AffiliationSelectionPageState extends State<_AffiliationSelectionPage> {
  List<String> _categories = [];
  List<Map<String, dynamic>> _affiliations = [];
  String? _selectedCategory;
  String? _selectedAffId;
  String? _selectedAffName;
  bool _loading = false;
  String? _error;
  late TextEditingController _otherCtrl;

  @override
  void initState() {
    super.initState();
    _selectedAffId = widget.initialId;
    _selectedAffName = widget.initialName;
    _otherCtrl = TextEditingController(text: widget.initialOther ?? "");
    _loadCategories();
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await AffiliationApi.fetchCategories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadAffiliations(String category) async {
    setState(() {
      _loading = true;
      _error = null;
      _affiliations = [];
      _selectedAffId = null;
      _selectedAffName = null;
    });
    try {
      final items = await AffiliationApi.fetchByCategory(category);
      if (!mounted) return;
      setState(() => _affiliations = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    if ((_selectedAffId == null || _selectedAffId!.isEmpty) &&
        _otherCtrl.text.trim().isEmpty) {
      _toast("Please choose an affiliation or type one.");
      return;
    }
    Navigator.of(context).pop(<String, String?>{
      "id": _selectedAffId,
      "name": _selectedAffName,
      "other": _otherCtrl.text.trim(),
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg, type: AppToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Affiliation"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
              value: _selectedCategory,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedCategory = val);
                if (val != null && val.isNotEmpty) {
                  _loadAffiliations(val);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: _loading ? "Loading..." : "Affiliation",
                border: const OutlineInputBorder(),
              ),
              value: _selectedAffId,
              isExpanded: true,
              items: _affiliations
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item["id"].toString(),
                      child: Text(item["name"]?.toString() ?? ""),
                    ),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (val) {
                      setState(() {
                        _selectedAffId = val;
                        final match = _affiliations
                            .firstWhere((e) => e["id"].toString() == val, orElse: () => {});
                        _selectedAffName = match["name"]?.toString();
                        _otherCtrl.clear();
                      });
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otherCtrl,
              decoration: const InputDecoration(
                labelText: "Other affiliation",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _selectedAffId = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: _submit,
                child: const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
