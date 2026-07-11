import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_info_section.dart';
import '../../widgets/profile/profile_goals_section.dart';
import '../../widgets/profile/profile_actions_section.dart';
import '../../localization/app_localizations.dart';
import '../../core/account_storage.dart';
import '../../config/base_url.dart';
import '../../services/auth/profile_service.dart';
import '../../services/auth/profile_storage.dart';
import '../../services/core/notification_service.dart';
import '../../screens/edit_profile_page.dart';
import '../../screens/welcome.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_back_button.dart';

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
  bool _isDeactivated = false;

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
    if (mounted) {
      setState(() {
        _error = null;
        if (_profile == null) _loading = true;
      });
    }
    final requestUserId = await AccountStorage.getUserId();
    final cachedAvatarRaw = await AccountStorage.getAvatarUrl(
      userId: requestUserId,
    );
    final cachedProfile = await ProfileStorage.loadProfile(
      userId: requestUserId,
    );
    final cachedProfileAvatar = _normalizeAvatarUrl(
      cachedProfile?["avatar_url"]?.toString(),
    );
    final cachedAvatar =
        _normalizeAvatarUrl(cachedAvatarRaw) ?? cachedProfileAvatar;
    final cachedAvatarPath = await AccountStorage.getAvatarPath(
      userId: requestUserId,
    );
    final activeUserIdBeforeHydration = await AccountStorage.getUserId();
    if (activeUserIdBeforeHydration != requestUserId) return;
    if (mounted) {
      setState(() {
        _avatarUrl = cachedAvatar;
        _avatarPath = cachedAvatarPath;
      });
    }
    // Hydrate from cache first to avoid blank UI.
    try {
      if (_profile == null) {
        if (cachedProfile != null && mounted) {
          setState(() {
            _profile = cachedProfile;
            _loading = false;
          });
        }
      }
    } catch (_) {}
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      if (requestUserId == null || requestUserId == 0) {
        if (!mounted) return;
        setState(() {
          _error = "user_missing";
          _loading = false;
          _avatarUrl = cachedAvatar;
          _avatarPath = cachedAvatarPath;
          _isDeactivated = false;
        });
        return;
      }
      try {
        final status = await ProfileApi.fetchAccountStatus(requestUserId);
        final value = (status["status"] ?? "").toString().toLowerCase().trim();
        final activeUserId = await AccountStorage.getUserId();
        if (mounted && activeUserId == requestUserId) {
          setState(() => _isDeactivated = value == "deactivated");
        }
      } catch (_) {}
      final data = await ProfileApi.fetchProfile(requestUserId, lang: lang);
      if (!mounted) return;
      final activeUserId = await AccountStorage.getUserId();
      if (activeUserId != requestUserId) return;
      final remoteAvatar = _normalizeAvatarUrl(data["avatar_url"]?.toString());
      if (remoteAvatar != null &&
          remoteAvatar.trim().isNotEmpty &&
          remoteAvatar != cachedAvatar &&
          mounted) {
        try {
          await precacheImage(
            CachedNetworkImageProvider(remoteAvatar),
            context,
          );
        } catch (_) {}
      }
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
      final activeUserId = await AccountStorage.getUserId();
      if (activeUserId != requestUserId) return;
      setState(() {
        if (_profile == null) {
          _error = e.toString();
        }
        _loading = false;
        _avatarUrl = cachedAvatar;
        _avatarPath = cachedAvatarPath;
      });
    }
  }

  String? _normalizeAvatarUrl(String? rawValue) {
    final raw = rawValue?.trim() ?? '';
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return raw;
    }
    final base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) return null;
    try {
      final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
      return baseUri.resolve(raw).toString();
    } catch (_) {
      return null;
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

  String? _resolveDisplayName() {
    if (_profile == null) return null;
    final firstName = _profile?["first_name"]?.toString().trim() ?? "";
    final lastName = _profile?["last_name"]?.toString().trim() ?? "";
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return "$firstName $lastName";
    }

    final fullName = _profile?["full_name"]?.toString().trim() ?? "";
    if (fullName.isNotEmpty) return fullName;

    final name = _profile?["name"]?.toString().trim() ?? "";
    if (name.isNotEmpty) return name;

    if (firstName.isNotEmpty) return firstName;
    if (lastName.isNotEmpty) return lastName;

    final username = _profile?["username"]?.toString().trim() ?? "";
    if (username.isNotEmpty) return username;

    return null;
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
      final parts = value
          .split(RegExp(r',\s*'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
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
    return target == candidate ||
        target.contains(candidate) ||
        candidate.contains(target);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // Translator

    final displayName = _resolveDisplayName();
    final occupation = _translateOption(
      "daily_activity",
      _profile?["occupation"],
      t,
    );
    final affiliationName = _profile?["affiliation_name"]?.toString();
    final affiliationOther = _profile?["affiliation_other_text"]?.toString();
    final affiliationDisplay =
        (affiliationName != null && affiliationName.trim().isNotEmpty)
        ? affiliationName
        : (affiliationOther != null && affiliationOther.trim().isNotEmpty)
        ? affiliationOther
        : "";
    final age = _profile?["age"]?.toString();
    final sex = _translateOption("sex", _profile?["sex"], t);
    final height = _profile?["height_cm"]?.toString();
    final weight = _profile?["weight_kg"]?.toString();
    final mainGoal = _translateOption(
      "fitness_goal",
      _profile?["fitness_goal"],
      t,
    );
    final trainingDays = _profile?["training_days"]?.toString();
    final dietType = _translateOption("diet_type", _profile?["diet_type"], t);
    final fitnessExperience = _translateOption(
      "fitness_experience",
      _profile?["fitness_experience"],
      t,
    );

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: TaqaUiScale.insetsLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: TaqaUiScale.h(25),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TaqaBackButton(
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                    Text(
                      t.translate("profile_title"),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        height: 25 / 15,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: (_error != null && _profile == null)
                  ? Center(
                      child: Text(
                        _error == "user_missing"
                            ? t.translate("user_missing")
                            : t.translate("network_error"),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProfile,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 24),
                        children: [
                          if (_loading)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: TaqaUiScale.h(12),
                              ),
                              child: LinearProgressIndicator(
                                color: TaqaUiColors.unnamedColorE4e93b,
                                backgroundColor: TaqaUiColors.unnamedColor1c1d17
                                    .withValues(alpha: 0.1),
                                minHeight: 2,
                              ),
                            ),
                          ProfileHeader(
                            name: _display(displayName),
                            occupation: _display(
                              affiliationDisplay.isNotEmpty
                                  ? affiliationDisplay
                                  : null,
                            ),
                            avatarUrl: _avatarUrl,
                            avatarPath: _avatarPath,
                          ),
                          SizedBox(height: TaqaUiScale.h(24)),
                          ProfileInfoSection(
                            age: _display(age),
                            sex: _display(sex),
                            height: _displayWithUnit(height, "cm"),
                            occupation: _display(occupation),
                            weight: _displayWithUnit(weight, "kg"),
                          ),
                          SizedBox(height: TaqaUiScale.h(15)),
                          ProfileGoalsSection(
                            mainGoal: _display(mainGoal),
                            workoutFreq: _displayDays(trainingDays),
                            dietPref: _display(dietType),
                            experience: _display(fitnessExperience),
                          ),
                          SizedBox(height: TaqaUiScale.h(15)),
                          if (_isDeactivated)
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(
                                bottom: TaqaUiScale.h(15),
                              ),
                              padding: TaqaUiScale.insetsLTRB(14, 10, 14, 10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.14),
                                borderRadius: TaqaUiScale.radius(15),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                t.translate(
                                  "profile_deactivated_edit_disabled",
                                ),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                            ),
                          ProfileActionsSection(
                            editEnabled: !_isDeactivated,
                            onEditProfile: () async {
                              if (_profile == null) return;
                              final updated = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditProfilePage(profile: _profile!),
                                ),
                              );
                              if (updated == true) {
                                _loadProfile();
                              }
                            },
                            onLogout: () async {
                              await AccountStorage.clearSessionOnly();
                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WelcomePage(fromLogout: true),
                                ),
                                (route) => false,
                              );
                              NotificationService.refreshDailyJournalRemindersForCurrentUser();
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
