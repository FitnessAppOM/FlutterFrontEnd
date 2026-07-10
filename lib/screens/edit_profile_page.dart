import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_back_button.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_underline_field.dart'
    show
        TaqaPillChoice,
        TaqaSectionHeading,
        TaqaUnderlineDropdown,
        TaqaUnderlineTextField;
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../core/account_storage.dart';
import '../../core/diet_regeneration_flag.dart';
import '../../localization/app_localizations.dart';
import '../../services/auth/profile_service.dart';
import '../../services/auth/affiliation_service.dart';
import '../../services/core/university_service.dart';
import '../../services/diet/diet_targets_storage.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/components/taqa_value_dialog.dart';
import 'updating_diet_screen.dart';
import 'updating_plan_screen.dart';

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
  bool? _isUniversityStudent;
  String? _universityId;
  String? _universityName;
  List<Map<String, dynamic>> _universities = [];
  bool _universitiesLoading = false;
  String? _universityError;

  String? _sex;
  String? _mainGoal;
  String? _trainingDays;
  String? _trainingLocation;
  String? _fitnessExperience;
  String? _dailyActivity;

  /// Diet preferences (multi-choice, same as questionnaire); "other" uses _dietOtherCtrl
  Set<String> _dietSelected = {};
  String? _trainingStyle;
  String? _chronicChoice;

  bool _saving = false;
  bool _hasValidationError = false;
  DateTime? _profileEditBlockedUntil;

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
    final t = AppLocalizations.of(context).translate;
    _ageCtrl.text = _str(p["age"]);
    _heightCtrl.text = _str(p["height_cm"]);
    _weightCtrl.text = _str(p["weight_kg"]);
    _pastInjuriesCtrl.text = _localizeInjury(_str(p["previous_injuries"]), t);

    _sex = _mapOptionKey(_str(p["sex"]), _sexOptions());
    // main_goal / fitness_goal: same 3 options as questionnaire
    final goalRaw = _str(p["fitness_goal"] ?? p["main_goal"]);
    _mainGoal =
        _mapOptionKey(goalRaw, _goalOptions()) ?? _mapLegacyGoal(goalRaw);
    _trainingDays = _matchOption(p["training_days"], _trainingDaysOptions());
    _trainingLocation = _matchOption(
      p["training_location"],
      _trainingLocationOptions(),
    );
    _fitnessExperience =
        _mapOptionKey(
          _str(p["fitness_experience"]),
          _fitnessExperienceOptions(),
        ) ??
        _matchOption(p["fitness_experience"], _fitnessExperienceOptions());
    _dailyActivity = _mapOptionKey(
      _str(p["occupation"]),
      _dailyActivityOptions(),
    );

    // Diet: API may return array (JSONB) or string; multi-choice same as questionnaire
    final dietRaw = p["diet_type"];
    List<String> dietParts = [];
    if (dietRaw is List) {
      dietParts = dietRaw
          .map((e) => _str(e))
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      final s = _str(dietRaw);
      if (s.isNotEmpty) {
        dietParts = s
            .split(RegExp(r',\s*'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    for (final part in dietParts) {
      final matched = _mapOptionKey(part, _dietOptions());
      if (matched != null) {
        _dietSelected.add(matched);
      } else {
        _dietSelected.add(_otherKey);
        _dietOtherCtrl.text = part;
      }
    }
    if (_dietSelected.isEmpty && dietParts.isNotEmpty) {
      _dietSelected.add(_otherKey);
      _dietOtherCtrl.text = dietParts.join(", ");
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

    final uniFlagRaw = p["is_university_student"];
    if (uniFlagRaw is bool) {
      _isUniversityStudent = uniFlagRaw;
    } else {
      final flagStr = _str(uniFlagRaw).toLowerCase();
      if (flagStr.isNotEmpty) {
        _isUniversityStudent =
            flagStr == "true" || flagStr == _t("yes").toLowerCase();
      }
    }
    final uniIdStr = _str(p["university_id"]);
    _universityId = (uniIdStr.isNotEmpty && uniIdStr != "0") ? uniIdStr : null;
    _universityName = _str(p["university_name"]);

    if (_isUniversityStudent == true) {
      _loadUniversities();
    }
  }

  Future<void> _loadUniversities() async {
    setState(() {
      _universitiesLoading = true;
      _universityError = null;
    });
    try {
      final items = await UniversityService.fetchUniversities();
      if (!mounted) return;
      setState(() {
        _universities = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _universityError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _universitiesLoading = false;
        });
      }
    }
  }

  String _t(String key) => AppLocalizations.of(context).translate(key);

  String _str(dynamic v) => v?.toString().trim() ?? "";

  String get _otherKey => "other";
  String get _otherLabel => _t("other");

  List<String> _sexOptions() => ["male", "female", "prefer_not"];
  // Main goal: same 3 options as questionnaire (Lose weight, Gain weight, Maintain weight)
  List<String> _goalOptions() => [
    "lose_weight",
    "gain_weight",
    "maintain_weight",
  ];
  List<String> _trainingDaysOptions() =>
      List<String>.generate(6, (i) => "${i + 1}");
  List<String> _trainingLocationOptions() => ["home", "gym"];
  List<String> _fitnessExperienceOptions() => [
    "beginner",
    "intermediate",
    "advanced",
  ];
  List<String> _dailyActivityOptions() => [
    "sedentary",
    "moderate",
    "active",
    "highly_active",
  ];
  // Match questionnaire diet_type options (multi-choice); "other" for backward compat
  List<String> _dietOptions() => [
    "no_pref",
    "high_protein",
    "low_carb",
    "vegetarian",
    "vegan",
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

  String _norm(String v) => v
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll('–', ' ')
      .trim();

  String? _mapOptionKey(String raw, List<String> keys) {
    final normalized = _norm(raw);
    for (final key in keys) {
      if (normalized == _norm(key) || normalized == _norm(_t(key))) {
        return key;
      }
    }
    return null;
  }

  /// Map legacy/API goal values to current options (lose_weight, gain_weight, maintain_weight)
  String? _mapLegacyGoal(String raw) {
    final n = _norm(raw);
    if (n == _norm("lose_fat") ||
        n == _norm("lose_weight") ||
        n == _norm(_t("lose_weight")))
      return "lose_weight";
    if (n == _norm("build_muscle") ||
        n == _norm("gain_muscle") ||
        n == _norm("gain_weight") ||
        n == _norm(_t("gain_muscle")) ||
        n == _norm(_t("gain_weight")))
      return "gain_weight";
    if (n == _norm("maintain") ||
        n == _norm("maintain_weight") ||
        n == _norm(_t("maintain_weight")))
      return "maintain_weight";
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

  String _localizeInjury(String raw, String Function(String) t) {
    final key = raw.trim().toLowerCase();
    const map = {
      "shoulder": "shoulder",
      "back": "back",
      "knee": "knee",
      "elbow": "elbow",
      "none": "none",
    };
    final matched = map[key];
    if (matched != null) return t(matched);
    return raw;
  }

  String _normalizeInjury(String input, String Function(String) t) {
    final val = input.trim();
    if (val.isEmpty) return val;
    final translations = {
      "shoulder": t("shoulder"),
      "back": t("back"),
      "knee": t("knee"),
      "elbow": t("elbow"),
      "none": t("none"),
    };
    for (final entry in translations.entries) {
      if (val.toLowerCase() == entry.value.toLowerCase()) return entry.key;
      if (val.toLowerCase() == entry.key.toLowerCase()) return entry.key;
    }
    return val;
  }

  String _formatDateTimeForMessage(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return "${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}";
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

    final persistedBlockedUntil =
        await AccountStorage.getProfileEditBlockedUntil();
    if (persistedBlockedUntil != null) {
      if (_profileEditBlockedUntil == null ||
          persistedBlockedUntil.isAfter(_profileEditBlockedUntil!)) {
        _profileEditBlockedUntil = persistedBlockedUntil;
      }
    }

    final blockedUntil = _profileEditBlockedUntil;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${_t("profile_update_failed")}: Next edit available at ${_formatDateTimeForMessage(blockedUntil)}",
        type: AppToastType.error,
      );
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
        AppToast.show(
          context,
          "$label: ${_t("invalid_number")}",
          type: AppToastType.error,
        );
      }
      return parsed;
    }

    String initialStr(String key) => _str(_initial[key]);

    final ageVal = parseInt(
      _t("age"),
      _ageCtrl.text,
      fallback: initialStr("age"),
    );
    final heightVal = parseInt(
      _t("height"),
      _heightCtrl.text,
      fallback: initialStr("height_cm"),
    );
    final weightVal = parseInt(
      _t("weight"),
      _weightCtrl.text,
      fallback: initialStr("weight_kg"),
    );

    final mainGoalKey =
        _mainGoal ??
        _mapOptionKey(initialStr("fitness_goal"), _goalOptions()) ??
        "";
    final trainingDaysKey =
        _trainingDays ??
        _mapOptionKey(initialStr("training_days"), _trainingDaysOptions()) ??
        "";
    final fitnessExpKey =
        _fitnessExperience ??
        _mapOptionKey(
          initialStr("fitness_experience"),
          _fitnessExperienceOptions(),
        ) ??
        "";
    final activityKey =
        _dailyActivity ??
        _mapOptionKey(initialStr("occupation"), _dailyActivityOptions()) ??
        "";

    // Diet: multi-choice → array (Profile Update API recommended format, same as questionnaire)
    final dietParts = _dietSelected
        .map((k) => k == _otherKey ? _dietOtherCtrl.text.trim() : k)
        .where((v) => v.isNotEmpty)
        .toList();
    final resolvedDietValue = dietParts.isEmpty ? null : dietParts;
    final resolvedDietForCompare = dietParts.isEmpty
        ? initialStr("diet_type")
        : dietParts.join(", ");
    String? resolvedTrainingKey =
        _trainingStyle ??
        _mapOptionKey(initialStr("training_style"), _trainingStyleOptions());
    if (resolvedTrainingKey == null && _trainingStyleCtrl.text.trim().isEmpty) {
      resolvedTrainingKey = initialStr("training_style").isNotEmpty
          ? _otherKey
          : null;
    }

    final pastInjuriesVal = _pastInjuriesCtrl.text.trim().isNotEmpty
        ? _normalizeInjury(_pastInjuriesCtrl.text.trim(), _t)
        : initialStr("previous_injuries");

    final chronicValueRaw = _chronicChoice == _t("no")
        ? "none"
        : (_chronicCtrl.text.trim().isNotEmpty
              ? _chronicCtrl.text.trim()
              : initialStr("pain"));
    final chronicValue = _isNone(chronicValueRaw) ? "none" : chronicValueRaw;

    final isStudent = _isUniversityStudent;
    int? universityIdVal;
    if (isStudent == true) {
      if (_universityId == null || _universityId!.isEmpty) {
        _hasValidationError = true;
        AppToast.show(
          context,
          _t("select_university"),
          type: AppToastType.error,
        );
      } else {
        universityIdVal = int.tryParse(_universityId!);
        if (universityIdVal == null || universityIdVal <= 0) {
          _hasValidationError = true;
          AppToast.show(
            context,
            _t("select_university"),
            type: AppToastType.error,
          );
        }
      }
    }

    if (_hasValidationError) return;

    final sexVal =
        (_sex ?? _mapOptionKey(initialStr("sex"), _sexOptions()) ?? "").trim();
    payload.addAll({
      "age": ageVal,
      "sex": sexVal.isEmpty ? null : sexVal,
      "height_cm": heightVal,
      "weight_kg": weightVal,
      "main_goal": mainGoalKey.isEmpty ? null : mainGoalKey,
      "training_days": trainingDaysKey.isEmpty ? null : trainingDaysKey,
      "fitness_experience": fitnessExpKey.isEmpty ? null : fitnessExpKey,
      "daily_activity": activityKey.isEmpty ? null : activityKey,
      "diet_type": resolvedDietValue,
      "training_style": resolvedTrainingKey == _otherKey
          ? _trainingStyleCtrl.text.trim()
          : resolvedTrainingKey,
      "past_injuries": pastInjuriesVal,
      "chronic_conditions": chronicValue,
    });

    if (isStudent != null) {
      payload["is_university_student"] = isStudent;
    }
    if (isStudent == true) {
      payload["university_id"] = universityIdVal;
    } else if (isStudent == false) {
      payload["university_id"] = 0;
    }

    final affIdStr = _affiliationId?.trim() ?? "";
    final affOtherStr = _affiliationOther?.trim() ?? "";
    payload["affiliation_id"] = affIdStr.isEmpty
        ? null
        : int.tryParse(affIdStr);
    payload["affiliation_other_text"] = affOtherStr;

    // Check if training days changed
    final initialTrainingDays =
        _mapOptionKey(initialStr("training_days"), _trainingDaysOptions()) ??
        "";
    final newTrainingDays = trainingDaysKey;
    final trainingDaysChanged = initialTrainingDays != newTrainingDays;

    // Check if training location changed — only send the field if it was modified
    final initialTrainingLocation =
        _matchOption(
          _str(_initial["training_location"]),
          _trainingLocationOptions(),
        ) ??
        "";
    final newTrainingLocation = _trainingLocation ?? initialTrainingLocation;
    final trainingLocationChanged =
        newTrainingLocation.isNotEmpty &&
        initialTrainingLocation != newTrainingLocation;
    if (trainingLocationChanged) {
      payload["training_location"] = newTrainingLocation;
    }

    // Check if main goal or nutrition (diet type) changed — we'll regenerate diet only after save
    final rawInitialGoal = (initialStr("fitness_goal").trim().isNotEmpty
        ? initialStr("fitness_goal")
        : initialStr("main_goal"));
    final initialMainGoal =
        _mapOptionKey(rawInitialGoal, _goalOptions()) ??
        _mapLegacyGoal(rawInitialGoal) ??
        rawInitialGoal.trim();
    final initialDiet = (initialStr("diet_type")).trim();
    // initialDiet may be stored as string or array; compare with normalized diet selection
    final initialDietNorm = (_initial["diet_type"] is List)
        ? (_initial["diet_type"] as List)
              .map((e) => _str(e))
              .where((s) => s.isNotEmpty)
              .join(", ")
        : initialDiet;
    final mainGoalOrDietChanged =
        (initialMainGoal != mainGoalKey) ||
        (initialDietNorm != resolvedDietForCompare);

    setState(() => _saving = true);

    // If training days or location changed, prompt the user before regenerating training + diet.
    if (trainingDaysChanged || trainingLocationChanged) {
      if (!mounted) return;
      final confirmed = await showTaqaConfirmDialog(
        context: context,
        title: _t("training_days_change_confirm_title"),
        message: _t("training_days_change_confirm_message"),
        confirmLabel: _t("common_confirm"),
        cancelLabel: _t("common_cancel"),
      );
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _saving = false);
        return;
      }
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => UpdatingPlanScreen(profilePayload: payload),
        ),
      );
      if (mounted) setState(() => _saving = false);
      return;
    }

    // If main goal or nutrition changed, confirm then show loading screen until diet is regenerated
    if (mainGoalOrDietChanged) {
      if (!mounted) return;
      final confirmed = await showTaqaConfirmDialog(
        context: context,
        title: _t("diet_plan_change_confirm_title"),
        message: _t("diet_plan_change_confirm_message"),
        confirmLabel: _t("common_confirm"),
        cancelLabel: _t("common_cancel"),
      );
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _saving = false);
        return;
      }
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => UpdatingDietScreen(profilePayload: payload),
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (result == true) {
        AppToast.show(
          context,
          _t("profile_update_success"),
          type: AppToastType.success,
        );
        Navigator.of(context).pop(true);
      }
      return;
    }

    try {
      final response = await ProfileApi.updateProfile(payload);
      if (!mounted) return;
      await AccountStorage.clearProfileEditBlockedUntil();
      _profileEditBlockedUntil = null;

      final dietPending =
          response['diet_pending'] == true ||
          response['diet_needs_regeneration'] == true;
      if (dietPending) {
        DietRegenerationFlag.setRegenerating();
        await DietTargetsStorage.clearTargets();
      }

      AppToast.show(
        context,
        _t("profile_update_success"),
        type: AppToastType.success,
      );

      Navigator.of(context).pop(true);
    } on ProfileUpdateCooldownException catch (e) {
      if (!mounted) return;
      final next = e.nextAllowedAt;
      if (next != null) {
        _profileEditBlockedUntil = next;
        await AccountStorage.setProfileEditBlockedUntil(next);
      }
      final msg = next != null
          ? "Next edit available at ${_formatDateTimeForMessage(next)}"
          : e.detail;
      AppToast.show(
        context,
        "${_t("profile_update_failed")}: $msg",
        type: AppToastType.error,
      );
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

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        appBar: TaqaPageAppBar(
          title: t.translate("edit_profile"),
          backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
          titleColor: TaqaUiColors.charcoal,
          showBackButton: !_saving,
          leading: _saving ? null : const TaqaBackButton(),
        ),
        body: SingleChildScrollView(
          padding: TaqaUiScale.insetsLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(t.translate("section_basics_title")),
                Row(
                  children: [
                    Expanded(child: _numberField(_ageCtrl, t.translate("age"))),
                    SizedBox(width: TaqaUiScale.w(12)),
                    Expanded(
                      child: _numberField(_heightCtrl, t.translate("height")),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(_weightCtrl, t.translate("weight")),
                    ),
                    SizedBox(width: TaqaUiScale.w(12)),
                    Expanded(
                      child: _dropdownField(
                        label: t.translate("sex"),
                        value: _sex,
                        options: _sexOptions(),
                        translateOptions: true,
                        onChanged: (v) => setState(() => _sex = v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _universitySection(),
                SizedBox(height: TaqaUiScale.h(12)),
                _sectionTitle(t.translate("affiliation")),
                _affiliationBlock(),
                SizedBox(height: TaqaUiScale.h(20)),
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
                SizedBox(height: TaqaUiScale.h(12)),
                _sectionTitle(t.translate("section_nutrition_title")),
                _dietMultiChoiceField(),
                SizedBox(height: TaqaUiScale.h(12)),
                _sectionTitle(t.translate("section_training_title")),
                _trainingLocationToggle(),
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
                SizedBox(height: TaqaUiScale.h(24)),
                Row(
                  children: [
                    Expanded(
                      child: TaqaFilledButton(
                        label: t.translate("common_save"),
                        onTap: _saving ? null : _submit,
                        loading: _saving,
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(12)),
                    Expanded(
                      child: TaqaTextActionButton(
                        label: t.translate("common_cancel"),
                        onTap: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return TaqaSectionHeading(title: title);
  }

  Widget _universitySection() {
    final t = AppLocalizations.of(context);
    final yes = t.translate("yes");
    final no = t.translate("no");
    final studentChoice = _isUniversityStudent == null
        ? null
        : (_isUniversityStudent! ? yes : no);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaqaUnderlineDropdown(
          label: t.translate("university_student_question"),
          value: studentChoice,
          options: [yes, no],
          validator: (_) => null,
          onChanged: (val) {
            setState(() {
              _isUniversityStudent = val == yes;
              if (_isUniversityStudent != true) {
                _universityId = null;
                _universityName = null;
              } else if (_universities.isEmpty && !_universitiesLoading) {
                _loadUniversities();
              }
            });
          },
        ),
        if (_isUniversityStudent == true) ...[
          SizedBox(height: TaqaUiScale.h(8)),
          TaqaUnderlineDropdown(
            label: t.translate("select_university"),
            value: _universityId,
            options: _universities
                .map((university) => university["id"].toString())
                .toList(growable: false),
            itemLabelBuilder: (id) => _resolveUniversityName(id) ?? id,
            onChanged: _universitiesLoading
                ? null
                : (val) {
                    setState(() {
                      _universityId = val;
                      _universityName = _resolveUniversityName(val);
                    });
                  },
            validator: (_) => null,
          ),
          if (_universitiesLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_universityError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _universityError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ],
    );
  }

  Widget _affiliationBlock() {
    final t = AppLocalizations.of(context);
    String subtitle = (_affiliationName != null && _affiliationName!.isNotEmpty)
        ? _affiliationName!
        : (_affiliationOther != null && _affiliationOther!.isNotEmpty)
        ? _affiliationOther!
        : "";
    if (subtitle.trim().isEmpty || subtitle.trim().toLowerCase() == "none") {
      subtitle = t.translate("not_set");
    }

    return Card(
      color: TaqaUiColors.white,
      shape: RoundedRectangleBorder(borderRadius: TaqaUiScale.radius(15)),
      child: Padding(
        padding: TaqaUiScale.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.translate("affiliation"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.charcoal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(4)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<Map<String, String?>>(
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
                foregroundColor: TaqaUiColors.charcoal,
                side: const BorderSide(color: TaqaUiColors.charcoal),
              ),
              child: Text(t.translate("set_button")),
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
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: TaqaUnderlineTextField(
        controller: controller,
        label: label,
        keyboardType: keyboardType,
        hint: hint,
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
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: TaqaUnderlineDropdown(
        label: label,
        value: value,
        options: options,
        itemLabelBuilder: (option) => translateOptions ? _t(option) : option,
        validator: (_) => null,
        onChanged: onChanged,
      ),
    );
  }

  /// Diet preference: multi-choice chips (same input type and options as questionnaire)
  Widget _dietMultiChoiceField() {
    final t = AppLocalizations.of(context);
    final options = _dietOptions();
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate("diet_type"),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
              fontSize: TaqaUiScale.sp(8),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          Wrap(
            spacing: TaqaUiScale.w(10),
            runSpacing: TaqaUiScale.h(10),
            children: options
                .map((option) {
                  final selected = _dietSelected.contains(option);
                  return TaqaPillChoice(
                    label: option == _otherKey ? _otherLabel : _t(option),
                    selected: selected,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _dietSelected.remove(option);
                          if (option == _otherKey) _dietOtherCtrl.clear();
                        } else {
                          _dietSelected.add(option);
                        }
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          if (_dietSelected.contains(_otherKey)) ...[
            const SizedBox(height: 8),
            _textField(_dietOtherCtrl, t.translate("other")),
          ],
        ],
      ),
    );
  }

  Widget _trainingLocationToggle() {
    final options = _trainingLocationOptions();
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t("training_location"),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
              fontSize: TaqaUiScale.sp(8),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          Wrap(
            spacing: TaqaUiScale.w(10),
            runSpacing: TaqaUiScale.h(10),
            children: options
                .map(
                  (option) => TaqaPillChoice(
                    label: _t(option),
                    selected: _trainingLocation == option,
                    onTap: () => setState(() => _trainingLocation = option),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _chronicChoiceField() {
    final yes = _t("yes");
    final no = _t("no");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaqaUnderlineDropdown(
          label: _t("chronic_prompt"),
          value: _chronicChoice,
          options: [yes, no],
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
          _textField(_chronicCtrl, _t("chronic_conditions")),
      ],
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg, type: AppToastType.error);
  }

  String? _resolveUniversityName(String? id) {
    if (id == null) return null;
    final match = _universities.firstWhere(
      (u) => u["id"].toString() == id,
      orElse: () => {},
    );
    final name = match["name"];
    return name?.toString();
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
  State<_AffiliationSelectionPage> createState() =>
      _AffiliationSelectionPageState();
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
  bool _useCustomAffiliation = false;

  @override
  void initState() {
    super.initState();
    _selectedAffId = widget.initialId;
    _selectedAffName = widget.initialName;
    _otherCtrl = TextEditingController(text: widget.initialOther ?? "");
    _useCustomAffiliation = _otherCtrl.text.trim().isNotEmpty;
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
      _toast(AppLocalizations.of(context).translate("affiliation_required"));
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
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: t.translate("affiliation"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      ),
      body: SingleChildScrollView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaqaUnderlineDropdown(
              label: t.translate("affiliation_category"),
              value: _selectedCategory,
              options: _categories,
              onChanged: (val) {
                setState(() => _selectedCategory = val);
                if (val != null && val.isNotEmpty) _loadAffiliations(val);
              },
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineDropdown(
              label: _loading
                  ? t.translate("affiliation_loading")
                  : t.translate("affiliation"),
              value: _selectedAffId,
              options: _affiliations
                  .map((item) => item["id"].toString())
                  .toList(growable: false),
              itemLabelBuilder: (id) {
                final match = _affiliations.firstWhere(
                  (item) => item["id"].toString() == id,
                  orElse: () => <String, dynamic>{},
                );
                return match["name"]?.toString() ?? id;
              },
              onChanged: _loading
                  ? null
                  : (val) {
                      setState(() {
                        _selectedAffId = val;
                        final match = _affiliations.firstWhere(
                          (item) => item["id"].toString() == val,
                          orElse: () => <String, dynamic>{},
                        );
                        _selectedAffName = match["name"]?.toString();
                        _otherCtrl.clear();
                        _useCustomAffiliation = false;
                      });
                    },
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() {
                  _useCustomAffiliation = true;
                  _selectedAffId = null;
                  _selectedAffName = null;
                }),
                child: Text(
                  t.translate("affiliation_other"),
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(12),
                    fontWeight: FontWeight.w600,
                    color: TaqaUiColors.charcoal,
                  ),
                ),
              ),
            ),
            if (_useCustomAffiliation) ...[
              SizedBox(height: TaqaUiScale.h(12)),
              TaqaUnderlineTextField(
                controller: _otherCtrl,
                label: t.translate("affiliation_other"),
                onChanged: (_) => setState(() {
                  _selectedAffId = null;
                  _selectedAffName = null;
                }),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: TaqaUiScale.h(8)),
              Text(
                _error!,
                style: TextStyle(color: TaqaUiColors.unnamedColorE93b3b),
              ),
            ],
            SizedBox(height: TaqaUiScale.h(28)),
            TaqaFilledButton(label: t.translate("common_save"), onTap: _submit),
          ],
        ),
      ),
    );
  }
}
