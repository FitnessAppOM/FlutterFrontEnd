class AccountType {
  static const String client = 'client';
  static const String coach = 'coach';

  static bool isCoach(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['is_developer'] == true) return true;
    final storedType = data['account_type']?.toString().trim().toLowerCase();
    return storedType == coach ||
        data['is_expert'] == true ||
        data['filled_expert_questionnaire'] == true;
  }

  /// An approved coach profile is authoritative onboarding evidence even if a
  /// legacy user row is missing its questionnaire-completion flag.
  static bool isApprovedCoach(Map<String, dynamic>? data) {
    if (data?['is_developer'] == true) return true;
    if (data == null || data['is_expert'] != true) return false;
    final status = data['expert_profile_status']
        ?.toString()
        .trim()
        .toLowerCase();
    return status == 'approved';
  }

  /// Admin and developer privileges bypass only the coach subscription gate.
  /// Coach approval is evaluated separately before this access check.
  static bool canUseCoachTools({
    required bool hasActiveCoachMembership,
    required bool isDeveloper,
    required bool isAdmin,
  }) {
    return hasActiveCoachMembership || isDeveloper || isAdmin;
  }
}
