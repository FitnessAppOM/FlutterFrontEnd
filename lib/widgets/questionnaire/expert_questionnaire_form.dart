import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../localization/app_localizations.dart';
import '../../services/auth/affiliation_service.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/components/taqa_selection_card.dart';
import '../../TaqaUI/components/taqa_underline_field.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import 'package:file_picker/file_picker.dart';
import '../../consents/consent_manager.dart';
import '../../services/core/expert_questionnaire_service.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import 'package:permission_handler/permission_handler.dart';

class ExpertQuestionnaireForm extends StatefulWidget {
  const ExpertQuestionnaireForm({
    super.key,
    required this.onSubmit,
    required this.submitting,
  });

  final Future<void> Function(Map<String, dynamic>)? onSubmit;
  final bool submitting;

  @override
  State<ExpertQuestionnaireForm> createState() =>
      _ExpertQuestionnaireFormState();
}

class _ExpertQuestionnaireFormState extends State<ExpertQuestionnaireForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, ExpertDocumentUpload> _documentUploads = {};

  String? _gender;
  String? _role;
  String? _hasCertification;
  String? _certType;
  String? _yearsExperience;
  String? _responseTime;
  String? _heardAbout;
  String? _joinReason;
  String? _onboarding;
  String? _referAsCoach;
  String? _nationality;
  String? _residence;
  DateTime? _selectedDob;
  bool _isAffiliated = false;

  // Sets for multi-choice
  final Set<String> _coreSpecialties = {};
  final Set<String> _preferredClients = {};
  final Set<String> _servicesOffer = {};
  final Set<String> _languages = {};
  final Set<String> _workSettings = {};

  // Affiliation
  String? _affiliationId;
  String? _affiliationOtherText;
  String? _affiliationName;

  // "Other" controllers
  final TextEditingController _coreOtherCtrl = TextEditingController();
  final TextEditingController _workOtherCtrl = TextEditingController();
  final TextEditingController _heardOtherCtrl = TextEditingController();
  final TextEditingController _joinOtherCtrl = TextEditingController();
  final TextEditingController _languageOtherCtrl = TextEditingController();
  final TextEditingController _certOtherCtrl = TextEditingController();
  final TextEditingController _certFileCtrl = TextEditingController();

  final List<String> _genderOpts = ["Male", "Female"];
  final List<String> _roleOpts = [
    "Personal Trainer",
    "Nutritionist",
    "Physiotherapist",
    "Strength & Conditioning Coach",
    "Sports Physician",
    "Sports Nutrition Specialist",
    "Yoga Instructor",
    "Pilates Instructor",
    "Mental Performance Coach",
    "Other",
  ];
  final List<String> _certOpts = [
    "ACE",
    "NASM",
    "ISSA",
    "RD",
    "DPT",
    "MD",
    "Other",
  ];
  final List<String> _yearsOpts = ["<1", "1–2", "3–5", "6–10", "10+"];
  final List<String> _coreOpts = [
    "Weight loss",
    "Muscle building & hypertrophy",
    "Strength and conditioning",
    "Functional training",
    "Endurance running",
    "Powerlifting",
    "CrossFit",
    "Body recomposition",
    "Prenatal/postnatal fitness",
    "Sports injury rehabilitation",
    "Chronic pain rehab",
    "Shoulder rehab",
    "Knee rehab",
    "Spine rehab",
    "Sports nutrition",
    "Clinical nutrition",
    "Meal planning",
    "Diabetes-friendly diets",
    "Cardiometabolic health",
    "Behavior change coaching",
    "Mental performance",
    "Other",
  ];
  final List<String> _preferredOpts = [
    "Beginners",
    "Intermediate",
    "Advanced",
    "Athletes",
    "Older Adults",
    "Individuals with chronic conditions",
    "Post-operative clients",
  ];
  final List<String> _servicesOpts = ["Training", "Nutrition"];
  final List<String> _responseOpts = ["<2h", "2–6h", "Same day", "Within 24h"];
  final List<String> _languageOpts = ["English", "Arabic", "French", "Other"];
  final List<String> _workSettingOpts = [
    "Gym",
    "Clinic",
    "Sports Club",
    "Hospital",
    "Online Coaching",
    "Other",
  ];
  final List<String> _heardOpts = [
    "Social media",
    "Referral",
    "Partner gym",
    "Other",
  ];
  final List<String> _joinReasonOpts = [
    "Growth",
    "More clients",
    "Professional network",
    "Other",
  ];
  final List<String> _onboardingOpts = ["Morning", "Afternoon", "Evening"];
  final List<String> _countryOpts = const [
    "United States",
    "United Kingdom",
    "Canada",
    "Australia",
    "Saudi Arabia",
    "United Arab Emirates",
    "Qatar",
    "Kuwait",
    "Bahrain",
    "Oman",
    "Jordan",
    "Lebanon",
    "Egypt",
    "Palestine",
    "Iraq",
    "Syria",
    "Yemen",
    "France",
    "Germany",
    "Spain",
    "Italy",
    "India",
    "Pakistan",
    "Bangladesh",
    "Philippines",
    "Other",
  ];

  TextEditingController _c(String key) =>
      _ctrl.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _coreOtherCtrl.dispose();
    _workOtherCtrl.dispose();
    _heardOtherCtrl.dispose();
    _joinOtherCtrl.dispose();
    _languageOtherCtrl.dispose();
    _certOtherCtrl.dispose();
    _certFileCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // required multi-selects
    if (_coreSpecialties.isEmpty ||
        _preferredClients.isEmpty ||
        _servicesOffer.isEmpty ||
        _languages.isEmpty ||
        _workSettings.isEmpty) {
      _toast("Please complete all required selections.");
      return;
    }

    if (_coreSpecialties.contains("Other") &&
        _coreOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify the other specialty.");
      return;
    }
    if (_workSettings.contains("Other") && _workOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify the other work setting.");
      return;
    }
    if (_languages.contains("Other") &&
        _languageOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify the other language.");
      return;
    }
    if (_heardAbout == "Other" && _heardOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify how you heard about Taqa Fitness.");
      return;
    }
    if (_joinReason == "Other" && _joinOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify why you want to join Taqa Fitness.");
      return;
    }

    // Certification validation (default to "No" if not selected)
    final certChoice = _hasCertification ?? "No";
    if (certChoice == "Yes") {
      if (_certType == null || _certType!.isEmpty) {
        _toast("Select certification type.");
        return;
      }
      if (_certType == "Other" && _certOtherCtrl.text.trim().isEmpty) {
        _toast("Enter your certification type.");
        return;
      }
      if (_certFileCtrl.text.trim().isEmpty) {
        _toast("Enter certification file URL.");
        return;
      }
    }

    final isAffiliated = _isAffiliated;
    final hasAffiliationId =
        _affiliationId != null && _affiliationId!.isNotEmpty;
    final otherAffiliation = (_affiliationOtherText ?? "").trim();
    if (isAffiliated && !hasAffiliationId && otherAffiliation.isEmpty) {
      _toast("Please add your affiliation.");
      return;
    }

    // Date validation
    final dob = _selectedDob != null
        ? DateFormat("yyyy-MM-dd").format(_selectedDob!)
        : null;
    if (dob == null) {
      _toast("Enter a valid date of birth.");
      return;
    }

    final selfieRaw = _c("selfie_file_url").text.trim();
    if (selfieRaw.isEmpty) {
      _toast("Please upload a selfie.");
      return;
    }
    if (_c("government_id_file_url").text.trim().isEmpty) {
      _toast("Please upload a government ID.");
      return;
    }
    if (!await _requiredDocumentScansAreClean(certChoice)) return;

    final selfieUrl = selfieRaw;
    final certFileUrl = certChoice == "No" ? "" : _certFileCtrl.text.trim();

    final data = <String, dynamic>{
      "full_name": _c("full_name").text.trim(),
      "date_of_birth": dob,
      "gender": _gender,
      "nationality": _nationality ?? "",
      "country_of_residence": _residence ?? "",
      "city_of_residence": _c("city_of_residence").text.trim(),
      "primary_phone_number": _c("primary_phone_number").text.trim(),
      "email_address": _c("email_address").text.trim(),
      "professional_role": _role,
      "professional_role_other": _c("professional_role_other").text.trim(),
      "certification_type": certChoice == "No" ? "" : _certType,
      "certification_type_other": certChoice == "No"
          ? ""
          : _certOtherCtrl.text.trim(),
      "certification_file_url": certFileUrl,
      "government_id_file_url": _c("government_id_file_url").text.trim(),
      "selfie_file_url": selfieUrl,
      "years_experience": _yearsExperience,
      "core_specialties": _coreSpecialties
          .map(
            (o) => o == "Other" && _coreOtherCtrl.text.trim().isNotEmpty
                ? _coreOtherCtrl.text.trim()
                : o,
          )
          .toList(),
      "preferred_client_types": _preferredClients.toList(),
      "services_to_offer": _servicesOffer.toList(),
      "expected_response_time": _responseTime,
      "languages": _languages
          .map(
            (lang) =>
                lang == "Other" && _languageOtherCtrl.text.trim().isNotEmpty
                ? _languageOtherCtrl.text.trim()
                : lang,
          )
          .toList(),
      "previous_work_settings": _workSettings
          .map(
            (o) => o == "Other" && _workOtherCtrl.text.trim().isNotEmpty
                ? _workOtherCtrl.text.trim()
                : o,
          )
          .toList(),
      "social_links": _c("social_links").text.trim(),
      "heard_about_taqa": _heardAbout == "Other"
          ? _heardOtherCtrl.text.trim()
          : _heardAbout,
      "join_reason": _joinReason == "Other"
          ? _joinOtherCtrl.text.trim()
          : _joinReason,
      "onboarding_availability": _onboarding,
      "refer_as_unassigned_coach": _referAsCoach == "Yes",
    };

    if (_isAffiliated) {
      if (_affiliationId != null && _affiliationId!.isNotEmpty) {
        data["affiliation_id"] = int.parse(_affiliationId!);
        data["affiliation_other_text"] = "";
      } else if ((_affiliationOtherText ?? "").trim().isNotEmpty) {
        data["affiliation_id"] = null;
        data["affiliation_other_text"] = _affiliationOtherText!.trim();
      } else {
        _toast("Please add your affiliation.");
        return;
      }
    } else {
      data["affiliation_id"] = null;
      data["affiliation_other_text"] = "";
    }

    await widget.onSubmit?.call(data);
  }

  void _toast(String msg, {AppToastType type = AppToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, msg, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Form description: ${t.translate("expert_questionnaire_intro_text")}",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(12),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(24)),

            const TaqaSectionHeading(title: "Affiliation"),
            Row(
              children: [
                TaqaPillChoice(
                  label: "Affiliated",
                  selected: _isAffiliated,
                  onTap: () => setState(() => _isAffiliated = true),
                ),
                SizedBox(width: TaqaUiScale.w(10)),
                TaqaPillChoice(
                  label: "Not affiliated",
                  selected: !_isAffiliated,
                  onTap: () {
                    setState(() {
                      _isAffiliated = false;
                      _affiliationId = null;
                      _affiliationOtherText = "";
                      _affiliationName = null;
                    });
                  },
                ),
              ],
            ),
            const TaqaSectionDivider(),

            const TaqaSectionHeading(title: "Certification & Files"),
            _affiliationSummary(),
            SizedBox(height: TaqaUiScale.h(12)),
            _certificateSummary(),
            SizedBox(height: TaqaUiScale.h(16)),
            Text(
              "Government Id",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            TaqaUploadRow(
              display: _documentDisplay("gov", _c("government_id_file_url")),
              actionLabel: "Upload",
              onTap: () => _pickAndUpload("gov", _c("government_id_file_url")),
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            Text(
              "Selfie",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            TaqaUploadRow(
              display: _documentDisplay("selfie", _c("selfie_file_url")),
              actionLabel: "Upload",
              onTap: () => _captureSelfie(_c("selfie_file_url")),
            ),
            const TaqaSectionDivider(),

            const TaqaSectionHeading(title: "Experience"),
            TaqaUnderlineDropdown(
              label: "Years of experience",
              value: _yearsExperience,
              options: _yearsOpts,
              onChanged: (v) => setState(() => _yearsExperience = v),
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            _multiChoiceWithOther(
              label: "Core Specialties",
              options: _coreOpts,
              target: _coreSpecialties,
              otherCtrl: _coreOtherCtrl,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            _multiChoice(
              "Preferred client types",
              _preferredOpts,
              _preferredClients,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            _multiChoice("Services to offer", _servicesOpts, _servicesOffer),
            const TaqaSectionDivider(),

            const TaqaSectionHeading(title: "Languages"),
            _multiChoiceWithOther(
              label: "Languages",
              options: _languageOpts,
              target: _languages,
              otherCtrl: _languageOtherCtrl,
              showLabel: false,
            ),
            const TaqaSectionDivider(),

            const TaqaSectionHeading(title: "Professional Role"),
            TaqaUnderlineDropdown(
              label: "Role",
              value: _role,
              options: _roleOpts,
              onChanged: (v) {
                setState(() {
                  _role = v;
                  if (v != "Other") _c("professional_role_other").clear();
                });
              },
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Required" : null,
            ),
            if (_role == "Other") ...[
              SizedBox(height: TaqaUiScale.h(12)),
              TaqaUnderlineTextField(
                controller: _c("professional_role_other"),
                label: "Specify role",
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? "Required" : null,
              ),
            ],
            const TaqaSectionDivider(),

            const TaqaSectionHeading(title: "Expectations & Preferences"),
            TaqaUnderlineDropdown(
              label: "Expected response time",
              value: _responseTime,
              options: _responseOpts,
              onChanged: (v) => setState(() => _responseTime = v),
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            _multiChoiceWithOther(
              label: "Previous work settings",
              options: _workSettingOpts,
              target: _workSettings,
              otherCtrl: _workOtherCtrl,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineTextField(
              controller: _c("social_links"),
              label: "Professional social links",
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            _dropdownWithOther(
              label: "How did you hear about Taqa Fitness?",
              value: _heardAbout,
              options: _heardOpts,
              otherCtrl: _heardOtherCtrl,
              onChanged: (v) => setState(() => _heardAbout = v),
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            _dropdownWithOther(
              label: "Why do you want to join Taqa Fitness?",
              value: _joinReason,
              options: _joinReasonOpts,
              otherCtrl: _joinOtherCtrl,
              onChanged: (v) => setState(() => _joinReason = v),
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineDropdown(
              label: "Onboarding call availability",
              value: _onboarding,
              options: _onboardingOpts,
              onChanged: (v) => setState(() => _onboarding = v),
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineDropdown(
              label: "Be referred clients automatically?",
              value: _referAsCoach,
              options: const ["Yes", "No"],
              onChanged: (v) => setState(() => _referAsCoach = v),
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Required" : null,
            ),
            const TaqaSectionDivider(),

            const TaqaSectionHeading(title: "Basics"),
            Text(
              "Full Name",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(11),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(4)),
            Row(
              children: [
                Expanded(
                  child: TaqaUnderlineTextField(
                    controller: _c("first_name"),
                    hint: "First Name",
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? "Required" : null,
                    onChanged: (_) => _syncFullName(),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(14)),
                Expanded(
                  child: TaqaUnderlineTextField(
                    controller: _c("last_name"),
                    hint: "Last Name",
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? "Required" : null,
                    onChanged: (_) => _syncFullName(),
                  ),
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _dobField()),
                SizedBox(width: TaqaUiScale.w(14)),
                Expanded(
                  child: TaqaUnderlineDropdown(
                    label: "Gender",
                    value: _gender,
                    options: _genderOpts,
                    onChanged: (v) => setState(() => _gender = v),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? "Required" : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineDropdown(
              label: "Nationality",
              value: _nationality,
              options: _countryOpts,
              onChanged: (v) => setState(() => _nationality = v),
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineDropdown(
              label: "Country Of Residence",
              value: _residence,
              options: _countryOpts,
              onChanged: (v) => setState(() => _residence = v),
              validator: (val) =>
                  (val == null || val.isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineTextField(
              controller: _c("city_of_residence"),
              label: "City",
              hint: "City",
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            Text(
              "Phone Number",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(11),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(4)),
            TaqaUnderlineTextField(
              controller: _c("primary_phone_number"),
              hint: "Number",
              keyboardType: TextInputType.phone,
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineTextField(
              controller: _c("email_address"),
              label: "Email",
              hint: "example@email.com",
              keyboardType: TextInputType.emailAddress,
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? "Required" : null,
            ),
            SizedBox(height: TaqaUiScale.h(28)),
            TaqaFilledButton(
              label: t.translate("expert_questionnaire_submit"),
              loading: widget.submitting,
              onTap: widget.submitting ? null : _submit,
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: double.infinity,
                  height: TaqaUiScale.h(44),
                  child: Center(
                    child: Text(
                      t.translate("cancel").toUpperCase(),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(10),
                        fontWeight: FontWeight.w600,
                        color: TaqaUiColors.unnamedColor1c1d17.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
          ],
        ),
      ),
    );
  }

  void _syncFullName() {
    final first = _c("first_name").text.trim();
    final last = _c("last_name").text.trim();
    _c("full_name").text = [first, last].where((s) => s.isNotEmpty).join(" ");
  }

  Widget _affiliationSummary() {
    final label = !_isAffiliated
        ? "Not affiliated"
        : _affiliationName ??
              (_affiliationOtherText?.isNotEmpty == true
                  ? _affiliationOtherText
                  : "Not set");
    return TaqaSelectionCard(
      label: "Affiliation",
      value: label ?? "Not set",
      buttonLabel: "Set",
      onTap: _isAffiliated ? _openAffiliationSelector : null,
    );
  }

  Widget _certificateSummary() {
    final status = _hasCertification ?? "Not set";
    final detail = _hasCertification == "Yes"
        ? (_certType ?? "Select type")
        : (_hasCertification == "No" ? "No certification" : "Not set");
    final label = _hasCertification == null ? "Not set" : "$status • $detail";
    return TaqaSelectionCard(
      label: "Certification",
      value: label,
      buttonLabel: "Set",
      onTap: _openCertificateSelector,
    );
  }

  String _documentDisplay(String kind, TextEditingController controller) {
    if (controller.text.trim().isEmpty) return "No file uploaded";
    final upload = _documentUploads[kind];
    if (upload == null) return "File uploaded";
    switch (upload.status) {
      case "clean":
        return "Ready - security scan passed";
      case "rejected":
        return "Rejected - upload another file";
      case "failed":
        return "Scan failed - upload again";
      default:
        return "Security scan pending";
    }
  }

  Future<bool> _requiredDocumentScansAreClean(String certChoice) async {
    final requiredKinds = <String>["gov", "selfie"];
    if (certChoice == "Yes") requiredKinds.add("cert");

    try {
      for (final kind in requiredKinds) {
        final upload = _documentUploads[kind];
        // Files loaded before this release have no document ID and are checked by the backend.
        if (upload == null) continue;
        final refreshed = await ExpertQuestionnaireApi.getUploadStatus(
          upload.documentId,
        );
        _documentUploads[kind] = refreshed;
      }
      if (mounted) setState(() {});
    } catch (e) {
      _toast("$e", type: AppToastType.error);
      return false;
    }

    for (final kind in requiredKinds) {
      final status = _documentUploads[kind]?.status;
      if (status == null || status == "clean") continue;
      if (status == "pending") {
        _toast("Document security scanning is still in progress.");
      } else {
        _toast(
          "A document did not pass security scanning. Upload it again.",
          type: AppToastType.error,
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _openAffiliationSelector() async {
    final result = await Navigator.of(context).push<Map<String, String?>>(
      MaterialPageRoute(
        builder: (_) => _AffiliationSelectionPage(
          initialId: _affiliationId,
          initialOther: _affiliationOtherText,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _isAffiliated = true;
      _affiliationId = result["id"];
      _affiliationOtherText = result["other"] ?? "";
      _affiliationName = (result["name"]?.isNotEmpty ?? false)
          ? result["name"]
          : _affiliationOtherText;
    });
  }

  Future<void> _openCertificateSelector() async {
    final result = await Navigator.of(context).push<Map<String, String?>>(
      MaterialPageRoute(
        builder: (_) => _CertificateSelectionPage(
          hasCertification: _hasCertification,
          certType: _certType,
          certTypeOther: _certOtherCtrl.text,
          certFileUrl: _certFileCtrl.text,
          documentId: _documentUploads["cert"]?.documentId,
          scanStatus: _documentUploads["cert"]?.status,
          certOpts: _certOpts,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _hasCertification = result["has"];
      _certType = result["type"];
      _certOtherCtrl.text = result["other"] ?? "";
      _certFileCtrl.text = result["file"] ?? "";
      final documentId = result["document_id"];
      if (documentId != null && documentId.isNotEmpty) {
        _documentUploads["cert"] = ExpertDocumentUpload(
          documentId: documentId,
          reference: result["file"] ?? "",
          status: result["scan_status"] ?? "pending",
        );
      } else {
        _documentUploads.remove("cert");
      }
    });
  }

  Widget _dobField() {
    final display = _selectedDob != null
        ? DateFormat("dd/MM/yyyy").format(_selectedDob!)
        : "";
    _c("date_of_birth_display").text = display;
    return TaqaUnderlineTextField(
      controller: _c("date_of_birth_display"),
      label: "Date Of Birth",
      hint: "DD/MM/YYYY",
      readOnly: true,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate:
              _selectedDob ?? DateTime(now.year - 20, now.month, now.day),
          firstDate: DateTime(1900, 1, 1),
          lastDate: DateTime(now.year, now.month, now.day),
        );
        if (picked != null) {
          setState(() {
            _selectedDob = picked;
          });
        }
      },
      validator: (_) => _selectedDob == null ? "Required" : null,
    );
  }

  Widget _multiChoice(String label, List<String> options, Set<String> target) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TaqaUiScale.w(10),
          runSpacing: TaqaUiScale.h(10),
          children: options.map((o) {
            final selected = target.contains(o);
            return TaqaPillChoice(
              label: o,
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    target.remove(o);
                  } else {
                    target.add(o);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (target.isEmpty) const TaqaRequiredHint(text: "Select at least one"),
      ],
    );
  }

  Widget _multiChoiceWithOther({
    required String label,
    required List<String> options,
    required Set<String> target,
    required TextEditingController otherCtrl,
    bool showLabel = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TaqaUiScale.w(10),
          runSpacing: TaqaUiScale.h(10),
          children: options.map((o) {
            final selected = target.contains(o);
            return TaqaPillChoice(
              label: o,
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    target.remove(o);
                    if (o == "Other") {
                      otherCtrl.clear();
                    }
                  } else {
                    target.add(o);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (target.contains("Other")) ...[
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaUnderlineTextField(
            controller: otherCtrl,
            label: "Other",
            validator: (val) {
              if (target.contains("Other") &&
                  (val == null || val.trim().isEmpty)) {
                return "Required";
              }
              return null;
            },
          ),
        ],
        if (target.isEmpty) const TaqaRequiredHint(text: "Select at least one"),
      ],
    );
  }

  Widget _dropdownWithOther({
    required String label,
    required String? value,
    required List<String> options,
    required TextEditingController otherCtrl,
    required ValueChanged<String?> onChanged,
  }) {
    final hasOther = options.contains("Other");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaqaUnderlineDropdown(
          label: label,
          value: value,
          options: options,
          validator: (val) {
            if (val == null || val.isEmpty) return "Required";
            if (val == "Other" && otherCtrl.text.trim().isEmpty) {
              return "Required";
            }
            return null;
          },
          onChanged: (val) {
            onChanged(val);
            if (val != "Other") {
              otherCtrl.clear();
            }
          },
        ),
        if (hasOther && value == "Other") ...[
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaUnderlineTextField(
            controller: otherCtrl,
            label: "Other",
            validator: (val) {
              if (value == "Other" && (val == null || val.trim().isEmpty)) {
                return "Required";
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Future<void> _pickAndUpload(
    String kind,
    TextEditingController controller,
  ) async {
    final permitted = await ConsentManager.requestFileAccessJIT();
    if (!permitted) {
      _toast("Permission required to access files.", type: AppToastType.error);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png", "heic", "heif", "webp", "pdf"],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > 5 * 1024 * 1024) {
      _toast("File must be 5MB or less.", type: AppToastType.error);
      return;
    }
    final path = file.path;
    if (path == null) {
      _toast("Invalid file.", type: AppToastType.error);
      return;
    }

    try {
      final upload = await ExpertQuestionnaireApi.upload(kind, path);
      setState(() {
        controller.text = upload.reference;
        _documentUploads[kind] = upload;
      });
      _toast("Uploaded. Security scan pending.", type: AppToastType.success);
    } catch (e) {
      _toast("$e", type: AppToastType.error);
    }
  }

  Future<void> _captureSelfie(TextEditingController controller) async {
    final cameraOk = await ConsentManager.requestCameraJIT();
    final photosOk = await ConsentManager.requestPhotosJIT();
    if (!cameraOk || !photosOk) {
      _toast(
        "Camera and Photos permissions are required to capture a selfie.",
        type: AppToastType.error,
      );
      await _maybePromptOpenSettingsForSelfie();
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) {
      await _maybePromptOpenSettingsForSelfie();
      return;
    }

    final file = File(picked.path);
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      _toast("File must be 5MB or less.", type: AppToastType.error);
      return;
    }

    try {
      final upload = await ExpertQuestionnaireApi.upload("selfie", picked.path);
      if (!mounted) return;
      setState(() {
        controller.text = upload.reference;
        _documentUploads["selfie"] = upload;
      });
      _toast("Uploaded. Security scan pending.", type: AppToastType.success);
    } catch (e) {
      _toast("$e", type: AppToastType.error);
    }
  }

  bool _isPermanentlyBlocked(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;

  Future<void> _maybePromptOpenSettingsForSelfie() async {
    if (!mounted) return;
    final cam = await Permission.camera.status;
    final photos = await Permission.photos.status;
    if (!mounted) return;
    final blocked = _isPermanentlyBlocked(cam) || _isPermanentlyBlocked(photos);
    if (!blocked) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permission required"),
        content: const Text(
          "Camera or Photos access is blocked. Enable both permissions in system settings to upload your selfie.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}

class _AffiliationSelectionPage extends StatefulWidget {
  const _AffiliationSelectionPage({
    required this.initialId,
    required this.initialOther,
  });
  final String? initialId;
  final String? initialOther;

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
  final TextEditingController _otherCtrl = TextEditingController();
  bool _useCustomAffiliation = false;

  @override
  void initState() {
    super.initState();
    _selectedAffId = widget.initialId;
    _otherCtrl.text = widget.initialOther ?? "";
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
      setState(() {
        _categories = cats;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
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
      setState(() {
        _affiliations = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    if ((_selectedAffId == null || _selectedAffId!.isEmpty) &&
        _otherCtrl.text.trim().isEmpty) {
      _toast(
        "Please choose an affiliation or type one.",
        type: AppToastType.error,
      );
      return;
    }
    Navigator.of(context).pop(<String, String?>{
      "id": _selectedAffId,
      "name": _selectedAffName,
      "other": _otherCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: const TaqaPageAppBar(title: "Affiliation"),
      body: SingleChildScrollView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaqaUnderlineDropdown(
              label: "Category",
              value: _selectedCategory,
              options: _categories,
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                });
                if (val != null && val.isNotEmpty) {
                  _loadAffiliations(val);
                }
              },
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TaqaUnderlineDropdown(
              label: _loading ? "Loading..." : "Affiliation",
              value: _selectedAffId,
              options: _affiliations
                  .map((item) => item["id"].toString())
                  .toList(),
              onChanged: _loading
                  ? null
                  : (val) {
                      setState(() {
                        _selectedAffId = val;
                        final match = _affiliations.firstWhere(
                          (e) => e["id"].toString() == val,
                          orElse: () => {},
                        );
                        _selectedAffName = match["name"]?.toString();
                        _otherCtrl.clear();
                      });
                    },
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _useCustomAffiliation = true;
                    _selectedAffId = null;
                    _selectedAffName = null;
                  });
                },
                child: Text(
                  "Can't find your affiliation?",
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(12),
                    fontWeight: FontWeight.w600,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ),
            ),

            if (_useCustomAffiliation) ...[
              SizedBox(height: TaqaUiScale.h(12)),
              TaqaUnderlineTextField(
                controller: _otherCtrl,
                label: "Type your affiliation",
                onChanged: (_) {
                  setState(() {
                    _selectedAffId = null;
                    _selectedAffName = null;
                  });
                },
              ),
            ],

            if (_error != null) ...[
              SizedBox(height: TaqaUiScale.h(8)),
              Text(
                _error!,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(12),
                  color: TaqaUiColors.unnamedColorE93b3b,
                ),
              ),
            ],
            SizedBox(height: TaqaUiScale.h(28)),
            TaqaFilledButton(label: "Save", onTap: _submit),
          ],
        ),
      ),
    );
  }

  void _toast(String msg, {AppToastType type = AppToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, msg, type: type);
  }
}

class _CertificateSelectionPage extends StatefulWidget {
  const _CertificateSelectionPage({
    required this.hasCertification,
    required this.certType,
    required this.certTypeOther,
    required this.certFileUrl,
    required this.documentId,
    required this.scanStatus,
    required this.certOpts,
  });

  final String? hasCertification;
  final String? certType;
  final String certTypeOther;
  final String certFileUrl;
  final String? documentId;
  final String? scanStatus;
  final List<String> certOpts;

  @override
  State<_CertificateSelectionPage> createState() =>
      _CertificateSelectionPageState();
}

class _CertificateSelectionPageState extends State<_CertificateSelectionPage> {
  String? _hasCert;
  String? _certType;
  late TextEditingController _otherCtrl;
  late TextEditingController _fileCtrl;
  String? _documentId;
  String? _scanStatus;

  @override
  void initState() {
    super.initState();
    _hasCert = widget.hasCertification ?? "No";
    _certType = widget.certType;
    _otherCtrl = TextEditingController(text: widget.certTypeOther);
    _fileCtrl = TextEditingController(text: widget.certFileUrl);
    _documentId = widget.documentId;
    _scanStatus = widget.scanStatus;
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    _fileCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_hasCert == "Yes") {
      if (_certType == null || _certType!.isEmpty) {
        _toast("Select certification type.", type: AppToastType.error);
        return;
      }
      if (_certType == "Other" && _otherCtrl.text.trim().isEmpty) {
        _toast("Enter your certification type.", type: AppToastType.error);
        return;
      }
      if (_fileCtrl.text.trim().isEmpty) {
        _toast("Enter certification file URL.", type: AppToastType.error);
        return;
      }
    }

    Navigator.of(context).pop(<String, String?>{
      "has": _hasCert,
      "type": _certType,
      "other": _otherCtrl.text.trim(),
      "file": _fileCtrl.text.trim(),
      "document_id": _documentId,
      "scan_status": _scanStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: const TaqaPageAppBar(title: "Certification"),
      body: SingleChildScrollView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaqaUnderlineDropdown(
              label: "Do you have a certification?",
              value: _hasCert,
              options: const ["Yes", "No"],
              onChanged: (val) {
                setState(() {
                  _hasCert = val;
                  if (val == "No") {
                    _certType = null;
                    _otherCtrl.clear();
                    _fileCtrl.clear();
                    _documentId = null;
                    _scanStatus = null;
                  }
                });
              },
            ),
            if (_hasCert == "Yes") ...[
              SizedBox(height: TaqaUiScale.h(16)),
              TaqaUnderlineDropdown(
                label: "Certification type",
                value: _certType,
                options: widget.certOpts,
                onChanged: (val) {
                  setState(() {
                    _certType = val;
                    if (val != "Other") _otherCtrl.clear();
                  });
                },
              ),
              if (_certType == "Other") ...[
                SizedBox(height: TaqaUiScale.h(16)),
                TaqaUnderlineTextField(
                  controller: _otherCtrl,
                  label: "Other certification",
                ),
              ],
              SizedBox(height: TaqaUiScale.h(16)),
              TaqaUploadRow(
                display: _fileCtrl.text.isEmpty
                    ? "No file uploaded"
                    : _scanStatus == "clean"
                    ? "Ready - security scan passed"
                    : _scanStatus == "rejected" || _scanStatus == "failed"
                    ? "Scan failed - upload again"
                    : "Security scan pending",
                actionLabel: "Upload",
                onTap: () => _pickAndUpload("cert"),
              ),
            ],
            SizedBox(height: TaqaUiScale.h(28)),
            TaqaFilledButton(label: "Save", onTap: _save),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(String kind) async {
    final permitted = await ConsentManager.requestFileAccessJIT();
    if (!permitted) {
      _toast("Permission required to access files.", type: AppToastType.error);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png", "heic", "heif", "webp", "pdf"],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > 5 * 1024 * 1024) {
      _toast("File must be 5MB or less.", type: AppToastType.error);
      return;
    }
    final path = file.path;
    if (path == null) {
      _toast("Invalid file.", type: AppToastType.error);
      return;
    }
    try {
      final upload = await ExpertQuestionnaireApi.upload(kind, path);
      setState(() {
        _fileCtrl.text = upload.reference;
        _documentId = upload.documentId;
        _scanStatus = upload.status;
      });
      _toast("Uploaded. Security scan pending.", type: AppToastType.success);
    } catch (e) {
      _toast("$e", type: AppToastType.error);
    }
  }

  void _toast(String msg, {AppToastType type = AppToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, msg, type: type);
  }
}
