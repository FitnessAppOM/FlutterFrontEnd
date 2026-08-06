class AccountType {
  static const String client = 'client';
  static const String coach = 'coach';

  static bool isCoach(Map<String, dynamic>? data) {
    if (data == null) return false;
    final storedType = data['account_type']?.toString().trim().toLowerCase();
    return storedType == coach ||
        data['is_expert'] == true ||
        data['filled_expert_questionnaire'] == true;
  }
}
