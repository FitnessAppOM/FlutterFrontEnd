import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../localization/app_localizations.dart';
import '../../services/affiliation_service.dart';
import '../../theme/app_theme.dart';
import '../primary_button.dart';
import 'package:file_picker/file_picker.dart';
import '../../consents/consent_manager.dart';
import '../../services/expert_questionnaire_service.dart';
import '../app_toast.dart';

class ExpertQuestionnaireForm extends StatefulWidget {
  const ExpertQuestionnaireForm({
    super.key,
    required this.onSubmit,
    required this.submitting,
  });

  final Future<void> Function(Map<String, dynamic>)? onSubmit;
  final bool submitting;

  @override
  State<ExpertQuestionnaireForm> createState() => _ExpertQuestionnaireFormState();
}

class _ExpertQuestionnaireFormState extends State<ExpertQuestionnaireForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _ctrl = {};

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
  final List<String> _certOpts = ["ACE", "NASM", "ISSA", "RD", "DPT", "MD", "Other"];
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
  final List<String> _heardOpts = ["Social media", "Referral", "Partner gym", "Other"];
  final List<String> _joinReasonOpts = ["Growth", "More clients", "Professional network", "Other"];
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

    if (_coreSpecialties.contains("Other") && _coreOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify the other specialty.");
      return;
    }
    if (_workSettings.contains("Other") && _workOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify the other work setting.");
      return;
    }
    if (_languages.contains("Other") && _languageOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify the other language.");
      return;
    }
    if (_heardAbout == "Other" && _heardOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify how you heard about TAQA.");
      return;
    }
    if (_joinReason == "Other" && _joinOtherCtrl.text.trim().isEmpty) {
      _toast("Please specify why you want to join TAQA.");
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
    final hasAffiliationId = _affiliationId != null && _affiliationId!.isNotEmpty;
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

    final selfieUrl = _c("selfie_file_url").text.trim().isEmpty
        ? "test-selfie-placeholder"
        : _c("selfie_file_url").text.trim();
    final certFileUrl =
        certChoice == "No" ? "" : _certFileCtrl.text.trim();

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
      "certification_type_other":
          certChoice == "No" ? "" : _certOtherCtrl.text.trim(),
      "certification_file_url": certFileUrl,
      "government_id_file_url": _c("government_id_file_url").text.trim(),
      "selfie_file_url": selfieUrl,
      "years_experience": _yearsExperience,
      "core_specialties": _coreSpecialties
          .map((o) => o == "Other" && _coreOtherCtrl.text.trim().isNotEmpty
              ? _coreOtherCtrl.text.trim()
              : o)
          .toList(),
      "preferred_client_types": _preferredClients.toList(),
      "services_to_offer": _servicesOffer.toList(),
      "expected_response_time": _responseTime,
      "languages": _languages
          .map((lang) => lang == "Other" && _languageOtherCtrl.text.trim().isNotEmpty
              ? _languageOtherCtrl.text.trim()
              : lang)
          .toList(),
      "previous_work_settings": _workSettings
          .map((o) => o == "Other" && _workOtherCtrl.text.trim().isNotEmpty
              ? _workOtherCtrl.text.trim()
              : o)
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
            _sectionTitle(t.translate("section_basics_title")),
            _textField(_c("full_name"), "Full name"),
            _dobField(),
            _dropdown("Gender", _gender, _genderOpts, (v) => setState(() => _gender = v)),
            _dropdown("Nationality", _nationality, _countryOpts,
                (v) => setState(() => _nationality = v)),
            _dropdown("Country of residence", _residence, _countryOpts,
                (v) => setState(() => _residence = v)),
            _textField(_c("city_of_residence"), "City of residence"),
            _textField(_c("primary_phone_number"), "Phone number"),
            _textField(_c("email_address"), "Email"),
            const SizedBox(height: 16),

            _sectionTitle("Professional Role"),
            _dropdown("Role", _role, _roleOpts, (v) {
              setState(() {
                _role = v;
                if (v != "Other") _c("professional_role_other").clear();
              });
            }),
            if (_role == "Other") _textField(_c("professional_role_other"), "Specify role"),
            const SizedBox(height: 16),

            _sectionTitle("Affiliation"),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text("Affiliated"),
                    selected: _isAffiliated,
                    onSelected: (v) {
                      setState(() {
                        _isAffiliated = true;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Not affiliated"),
                    selected: !_isAffiliated,
                    onSelected: (v) {
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
            ),
            _affiliationSummary(),
            const SizedBox(height: 16),

            _sectionTitle("Certifications & Files"),
            _certificateSummary(),
            _uploadField("Government ID", _c("government_id_file_url"), "gov"),
            _uploadField("Selfie", _c("selfie_file_url"), "selfie"),
            const SizedBox(height: 16),

            _sectionTitle("Experience"),
            _dropdown("Years of experience", _yearsExperience, _yearsOpts,
                (v) => setState(() => _yearsExperience = v)),
            _multiChoiceWithOther(
              label: "Core specialties",
              options: _coreOpts,
              target: _coreSpecialties,
              otherCtrl: _coreOtherCtrl,
            ),
            _multiChoice("Preferred client types", _preferredOpts, _preferredClients),
            _multiChoice("Services to offer", _servicesOpts, _servicesOffer),
            const SizedBox(height: 16),

            _sectionTitle("Expectations & Preferences"),
            _dropdown("Expected response time", _responseTime, _responseOpts,
                (v) => setState(() => _responseTime = v)),
            _multiChoiceWithOther(
              label: "Languages",
              options: _languageOpts,
              target: _languages,
              otherCtrl: _languageOtherCtrl,
            ),
            _multiChoiceWithOther(
              label: "Previous work settings",
              options: _workSettingOpts,
              target: _workSettings,
              otherCtrl: _workOtherCtrl,
            ),
            _textField(_c("social_links"), "Professional social links", required: false),
            _dropdownWithOther(
              label: "How did you hear about TAQA?",
              value: _heardAbout,
              options: _heardOpts,
              otherCtrl: _heardOtherCtrl,
              onChanged: (v) => setState(() => _heardAbout = v),
            ),
            _dropdownWithOther(
              label: "Why do you want to join TAQA?",
              value: _joinReason,
              options: _joinReasonOpts,
              otherCtrl: _joinOtherCtrl,
              onChanged: (v) => setState(() => _joinReason = v),
            ),
            _dropdown("Onboarding call availability", _onboarding, _onboardingOpts,
                (v) => setState(() => _onboarding = v)),
            _dropdown("Be referred clients automatically?", _referAsCoach, ["Yes", "No"],
                (v) => setState(() => _referAsCoach = v)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: widget.submitting ? null : _submit,
                child: widget.submitting
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.translate("cancel")),
              ),
            ),
          ],
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
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _affiliationSummary() {
    final label = !_isAffiliated
        ? "Not affiliated"
        : _affiliationName ??
            (_affiliationOtherText?.isNotEmpty == true
                ? _affiliationOtherText
                : "Not set");
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Affiliation",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  label ?? "Not set",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isAffiliated ? _openAffiliationSelector : null,
            child: const Text("Set"),
          ),
        ],
      ),
    );
  }

  Widget _certificateSummary() {
    final status = _hasCertification ?? "Not set";
    final detail = _hasCertification == "Yes"
        ? (_certType ?? "Select type")
        : (_hasCertification == "No" ? "No certification" : "Not set");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Certification",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  "$status • $detail",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openCertificateSelector,
            child: const Text("Set"),
          ),
        ],
      ),
    );
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
    });
  }

  Widget _dobField() {
    final display = _selectedDob != null
        ? DateFormat("yyyy-MM-dd").format(_selectedDob!)
        : "";
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDob ?? DateTime(now.year - 20, now.month, now.day),
            firstDate: DateTime(1900, 1, 1),
            lastDate: DateTime(now.year, now.month, now.day),
          );
          if (picked != null) {
            setState(() {
              _selectedDob = picked;
            });
          }
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: "Date of birth",
            border: OutlineInputBorder(),
          ),
          child: Text(
            display.isEmpty ? "Tap to pick" : display,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label,
      {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(color: Colors.white),
        validator: (val) {
          if (required && (val == null || val.trim().isEmpty)) {
            return "Required";
          }
          return null;
        },
      ),
    );
  }

  Widget _dropdown(
      String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        initialValue: value,
        dropdownColor: AppColors.black,
        style: const TextStyle(color: Colors.white),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        validator: (val) {
          if (val == null || val.isEmpty) return "Required";
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }

  Widget _multiChoice(String label, List<String> options, Set<String> target) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: options.map((o) {
              final selected = target.contains(o);
              return FilterChip(
                label: Text(o),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      target.add(o);
                    } else {
                      target.remove(o);
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (target.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Select at least one",
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _multiChoiceWithOther({
    required String label,
    required List<String> options,
    required Set<String> target,
    required TextEditingController otherCtrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: options.map((o) {
              final selected = target.contains(o);
              return FilterChip(
                label: Text(o),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      target.add(o);
                    } else {
                      target.remove(o);
                      if (o == "Other") {
                        otherCtrl.clear();
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (target.contains("Other")) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: otherCtrl,
              decoration: const InputDecoration(
                labelText: "Other",
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (target.contains("Other") &&
                    (val == null || val.trim().isEmpty)) {
                  return "Required";
                }
                return null;
              },
            ),
          ],
          if (target.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Select at least one",
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            initialValue: value,
            dropdownColor: AppColors.black,
            style: const TextStyle(color: Colors.white),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
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
            const SizedBox(height: 8),
            TextFormField(
              controller: otherCtrl,
              decoration: const InputDecoration(
                labelText: "Other",
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (value == "Other" && (val == null || val.trim().isEmpty)) {
                  return "Required";
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _uploadField(String label, TextEditingController controller, String kind) {
    final isSelfie = kind == "selfie";
    final display = controller.text.isEmpty ? "No file uploaded" : controller.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: isSelfie
                      ? () => _captureSelfie(controller)
                      : () => _pickAndUpload(kind, controller),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isSelfie ? "Capture" : "Upload"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(String kind, TextEditingController controller) async {
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
      final url = await ExpertQuestionnaireApi.upload(kind, path);
      setState(() {
        controller.text = url;
      });
      _toast("Uploaded", type: AppToastType.success);
    } catch (e) {
      _toast("$e", type: AppToastType.error);
    }
  }

  Future<void> _captureSelfie(TextEditingController controller) async {
    final cameraOk = await ConsentManager.requestCameraJIT();
    final photosOk = await ConsentManager.requestPhotosJIT();
    if (!cameraOk || !photosOk) {
      _toast("Camera/Photos permission required.", type: AppToastType.error);
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
    if (picked == null) return;

    final file = File(picked.path);
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      _toast("File must be 5MB or less.", type: AppToastType.error);
      return;
    }

    try {
      final url = await ExpertQuestionnaireApi.upload("selfie", picked.path);
      if (!mounted) return;
      setState(() {
        controller.text = url;
      });
      _toast("Uploaded", type: AppToastType.success);
    } catch (e) {
      _toast("$e", type: AppToastType.error);
    }
  }
}

class _AffiliationSelectionPage extends StatefulWidget {
  const _AffiliationSelectionPage({required this.initialId, required this.initialOther});
  final String? initialId;
  final String? initialOther;

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
      _toast("Please choose an affiliation or type one.", type: AppToastType.error);
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
      appBar: AppBar(
        title: const Text("Affiliation"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedCategory,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                });
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
              initialValue: _selectedAffId,
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
            TextButton(
              onPressed: () {
                setState(() {
                  _useCustomAffiliation = true;
                  _selectedAffId = null;
                  _selectedAffName = null;
                });
              },
              child: const Text("Can’t find your affiliation?"),
            ),

            if (_useCustomAffiliation) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _otherCtrl,
                decoration: const InputDecoration(
                  labelText: "Type your affiliation",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {
                    _selectedAffId = null;
                    _selectedAffName = null;
                  });
                },
              ),
            ],

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
    required this.certOpts,
  });

  final String? hasCertification;
  final String? certType;
  final String certTypeOther;
  final String certFileUrl;
  final List<String> certOpts;

  @override
  State<_CertificateSelectionPage> createState() => _CertificateSelectionPageState();
}

class _CertificateSelectionPageState extends State<_CertificateSelectionPage> {
  String? _hasCert;
  String? _certType;
  late TextEditingController _otherCtrl;
  late TextEditingController _fileCtrl;

  @override
  void initState() {
    super.initState();
    _hasCert = widget.hasCertification ?? "No";
    _certType = widget.certType;
    _otherCtrl = TextEditingController(text: widget.certTypeOther);
    _fileCtrl = TextEditingController(text: widget.certFileUrl);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Certification")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Do you have a certification?",
                border: OutlineInputBorder(),
              ),
              initialValue: _hasCert,
              items: const [
                DropdownMenuItem(value: "Yes", child: Text("Yes")),
                DropdownMenuItem(value: "No", child: Text("No")),
              ],
              onChanged: (val) {
                setState(() {
                  _hasCert = val;
                  if (val == "No") {
                    _certType = null;
                    _otherCtrl.clear();
                    _fileCtrl.clear();
                  }
                });
              },
            ),
            if (_hasCert == "Yes") ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Certification type",
                  border: OutlineInputBorder(),
                ),
                initialValue: _certType,
                items: widget.certOpts
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _certType = val;
                    if (val != "Other") _otherCtrl.clear();
                  });
                },
              ),
              if (_certType == "Other") ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otherCtrl,
                  decoration: const InputDecoration(
                    labelText: "Other certification",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fileCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Certification file",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _pickAndUpload("cert"),
                    child: const Text("Upload"),
                  ),
                ],
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: _save,
                child: const Text("Save"),
              ),
            ),
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
      final url = await ExpertQuestionnaireApi.upload(kind, path);
      setState(() {
        _fileCtrl.text = url;
      });
      _toast("Uploaded", type: AppToastType.success);
    } catch (e) {
      _toast("$e", type: AppToastType.error);
    }
  }

  void _toast(String msg, {AppToastType type = AppToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, msg, type: type);
  }
}
