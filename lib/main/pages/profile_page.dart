import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_info_section.dart';
import '../../widgets/profile/profile_goals_section.dart';
import '../../widgets/profile/profile_actions_section.dart';
import '../../localization/app_localizations.dart';
import '../../core/account_storage.dart';
import '../../services/profile_service.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  String? _avatarUrl;
  bool _didLoadProfile = false;

  @override
  void initState() {
    super.initState();
    // Wait for localization to be available before loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fallback if post-frame never fired (defensive)
    if (!_didLoadProfile) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    _didLoadProfile = true;
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      final avatar = await AccountStorage.getAvatarUrl();
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        setState(() {
          _error = "user_missing";
          _loading = false;
          _avatarUrl = avatar;
        });
        return;
      }
      final data = await ProfileApi.fetchProfile(userId, lang: lang);
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
        _avatarUrl = data["avatar_url"]?.toString() ?? avatar;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _display(String? value) => (value == null || value.isEmpty) ? "—" : value;
  String _displayWithUnit(String? value, String unit) {
    if (value == null || value.isEmpty) return "—";
    return "$value $unit";
  }
  String _displayDays(String? value) {
    if (value == null || value.isEmpty) return "—";
    return "$value ${AppLocalizations.of(context).translate("profile_days_per_week")}";
  }

  String _translateOption(String field, dynamic raw, AppLocalizations t) {
    if (raw == null) return "";
    final value = raw.toString().trim();
    if (value.isEmpty) return "";

    final normalized = _normalizeValue(value);

    const Map<String, List<String>> optionKeys = {
      "sex": ["male", "female", "prefer_not"],
      "daily_activity": ["sedentary", "moderate", "active", "highly_active"],
      "fitness_goal": [
        "lose_weight",
        "gain_muscle",
        "improve_endurance",
        "maintain_fitness",
        "improve_health",
      ],
      "diet_type": [
        "no_pref",
        "high_protein",
        "low_carb",
        "vegetarian",
        "vegan",
        "fasting",
        "other",
      ],
      "fitness_experience": ["beginner", "intermediate", "advanced"],
    };

    final keys = optionKeys[field];
    if (keys == null) return value;

    final en = AppLocalizations(const Locale('en'));
    final ar = AppLocalizations(const Locale('ar'));

    for (final key in keys) {
      final normalizedKey = _normalizeValue(key);
      final normalizedEn = _normalizeValue(en.translate(key));
      final normalizedAr = _normalizeValue(ar.translate(key));

      final matches = _matches(normalized, normalizedKey) ||
          _matches(normalized, normalizedEn) ||
          _matches(normalized, normalizedAr);

      if (matches) {
        // Preserve custom "other" text; otherwise translate to current locale
        if (key == "other") return value;
        return t.translate(key);
      }
    }

    return value;
  }

  String _normalizeValue(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matches(String target, String candidate) {
    if (candidate.isEmpty) return false;
    return target == candidate || target.contains(candidate) || candidate.contains(target);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // Translator

    final name = _profile?["name"]?.toString();
    final occupation =
        _translateOption("daily_activity", _profile?["occupation"], t);
    final affiliationName = _profile?["affiliation_name"]?.toString();
    final affiliationOther = _profile?["affiliation_other_text"]?.toString();
    final affiliationDisplay = (affiliationName != null && affiliationName.trim().isNotEmpty)
        ? affiliationName
        : (affiliationOther != null && affiliationOther.trim().isNotEmpty)
            ? affiliationOther
            : "";
    final age = _profile?["age"]?.toString();
    final sex = _translateOption("sex", _profile?["sex"], t);
    final height = _profile?["height_cm"]?.toString();
    final weight = _profile?["weight_kg"]?.toString();
    final mainGoal =
        _translateOption("fitness_goal", _profile?["fitness_goal"], t);
    final trainingDays = _profile?["training_days"]?.toString();
    final dietType =
        _translateOption("diet_type", _profile?["diet_type"], t);
    final fitnessExperience = _translateOption(
      "fitness_experience",
      _profile?["fitness_experience"],
      t,
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text(
          t.translate("profile_title"),
        ),
        backgroundColor: AppColors.black,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error == "user_missing"
                        ? t.translate("user_missing")
                        : t.translate("network_error"),
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  color: AppColors.accent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileHeader(
                              name: _display(name),
                              occupation: affiliationDisplay.isNotEmpty ? affiliationDisplay : null,
                              avatarUrl: _avatarUrl,
                            ),
                            const SizedBox(height: 24),
                            ProfileInfoSection(
                              age: _display(age),
                              sex: _display(sex),
                              height: _displayWithUnit(height, "cm"),
                              occupation: _display(occupation),
                              weight: _displayWithUnit(weight, "kg"),
                            ),
                            const SizedBox(height: 24),
                            ProfileGoalsSection(
                              mainGoal: _display(mainGoal),
                              workoutFreq: _displayDays(trainingDays),
                              dietPref: _display(dietType),
                              experience: _display(fitnessExperience),
                            ),
                            const SizedBox(height: 24),
                        ProfileActionsSection(
                          onEditProfile: () async {
                            if (_profile == null) return;
                            final updated = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditProfilePage(
                                  profile: _profile!,
                                ),
                              ),
                            );
                            if (updated == true) {
                              _loadProfile();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
