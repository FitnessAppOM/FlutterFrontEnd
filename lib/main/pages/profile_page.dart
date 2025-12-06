import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_info_section.dart';
import '../../widgets/profile/profile_goals_section.dart';
import '../../widgets/profile/profile_actions_section.dart';
import '../../localization/app_localizations.dart';
import '../../core/account_storage.dart';
import '../../services/profile_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
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
      final data = await ProfileApi.fetchProfile(userId);
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

    final normalized = value.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');

    const Map<String, Map<String, String>> map = {
      "sex": {
        "male": "male",
        "female": "female",
        "prefer not to say": "prefer_not",
      },
      "daily_activity": {
        "sedentary": "sedentary",
        "moderate": "moderate",
        "active": "active",
        "highly active": "highly_active",
      },
      "fitness_goal": {
        "lose weight": "lose_weight",
        "gain muscle": "gain_muscle",
        "improve endurance": "improve_endurance",
        "maintain fitness": "maintain_fitness",
        "improve health": "improve_health",
      },
      "diet_type": {
        "no pref": "no_pref",
        "no preference": "no_pref",
        "high protein": "high_protein",
        "low carb": "low_carb",
        "vegetarian": "vegetarian",
        "vegan": "vegan",
        "fasting": "fasting",
        "other": "other",
      },
      "fitness_experience": {
        "beginner": "beginner",
        "intermediate": "intermediate",
        "intermidiate": "intermediate",
        "advanced": "advanced",
      },
    };

    // Loose matching for experience strings like "Intermediate (6–24 months)"
    if (field == "fitness_experience") {
      if (normalized.contains("beginner")) {
        return t.translate("beginner");
      }
      if (normalized.contains("intermediate") || normalized.contains("intermidiate")) {
        return t.translate("intermediate");
      }
      if (normalized.contains("advanced")) {
        return t.translate("advanced");
      }
    }

    final fieldMap = map[field];
    if (fieldMap == null) return value;

    final key = fieldMap[normalized];
    if (key == null) return value;

    return t.translate(key);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // Translator

    final name = _profile?["name"]?.toString();
    final occupation =
        _translateOption("daily_activity", _profile?["occupation"], t);
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
                          occupation: _display(occupation),
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
                        const ProfileActionsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }
}
