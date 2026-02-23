import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_info_section.dart';
import '../../widgets/profile/profile_goals_section.dart';
import '../../widgets/profile/profile_actions_section.dart';
import '../../localization/app_localizations.dart';
import '../../core/account_storage.dart';
import '../../services/auth/profile_service.dart';
import '../../screens/edit_profile_page.dart';

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
  String? _avatarPath;
  bool _didLoadProfile = false;

  @override
  void initState() {
    super.initState();
    AccountStorage.accountChange.addListener(_onAccountChanged);
    // Wait for localization to be available before loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
      }
    });
  }

  @override
  void dispose() {
    AccountStorage.accountChange.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _didLoadProfile = false;
    _loadProfile();
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
    if (mounted) setState(() { _error = null; _loading = true; });
    final cachedAvatar = await AccountStorage.getAvatarUrl();
    final cachedAvatarPath = await AccountStorage.getAvatarPath();
    if (mounted) {
      setState(() {
        _avatarUrl = cachedAvatar;
        _avatarPath = cachedAvatarPath;
      });
    }
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId == 0) {
        if (!mounted) return;
        setState(() {
          _error = "user_missing";
          _loading = false;
          _avatarUrl = cachedAvatar;
          _avatarPath = cachedAvatarPath;
        });
        return;
      }
      final data = await ProfileApi.fetchProfile(userId, lang: lang);
      if (!mounted) return;
      final remoteAvatar = data["avatar_url"]?.toString();
      final normalizedAvatar =
          (remoteAvatar != null && remoteAvatar.trim().isNotEmpty)
              ? remoteAvatar
              : cachedAvatar;
      setState(() {
        _profile = data;
        _loading = false;
        _avatarUrl = normalizedAvatar;
        _avatarPath = cachedAvatarPath;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _avatarUrl = cachedAvatar;
        _avatarPath = cachedAvatarPath;
      });
    }
  }

  String _display(String? value) {
    if (value == null) return "—";
    final v = value.trim();
    if (v.isEmpty) return "—";
    if (v.toLowerCase() == "none") {
      return AppLocalizations.of(context).translate("not_set");
    }
    return v;
  }
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
    // diet_type may be array (API JSONB) or string
    if (field == "diet_type" && raw is List) {
      final parts = <String>[];
      for (final e in raw) {
        final s = e?.toString().trim();
        if (s != null && s.isNotEmpty) parts.add(s);
      }
      return parts.map((p) => _translateOption("diet_type", p, t)).join(", ");
    }
    final value = raw.toString().trim();
    if (value.isEmpty) return "";

    // diet_type can be comma-separated string (multi-choice)
    if (field == "diet_type" && value.contains(",")) {
      final parts = value.split(RegExp(r',\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty);
      return parts.map((p) => _translateOption("diet_type", p, t)).join(", ");
    }

    final normalized = _normalizeValue(value);

    // Option keys aligned with questionnaire (and edit profile)
    const Map<String, List<String>> optionKeys = {
      "sex": ["male", "female", "prefer_not"],
      "daily_activity": ["sedentary", "moderate", "active", "highly_active"],
      "fitness_goal": [
        "lose_weight",
        "gain_weight",
        "maintain_weight",
        "lose_fat",
        "build_muscle",
        "maintain",
        "gain_muscle",
      ],
      "diet_type": [
        "no_pref",
        "high_protein",
        "low_carb",
        "vegetarian",
        "vegan",
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

      final matches = field == "sex"
          ? (normalized == normalizedKey ||
              normalized == normalizedEn ||
              normalized == normalizedAr)
          : (_matches(normalized, normalizedKey) ||
              _matches(normalized, normalizedEn) ||
              _matches(normalized, normalizedAr));

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
      occupation: _display(affiliationDisplay.isNotEmpty ? affiliationDisplay : null),
      avatarUrl: _avatarUrl,
      avatarPath: _avatarPath,
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
