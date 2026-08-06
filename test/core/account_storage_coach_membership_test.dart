import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/account_storage.dart';

void main() {
  const userId = 42;

  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': userId});
  });

  test('does not activate coach membership without an expiration', () async {
    await AccountStorage.setCoachMembershipActive(true);

    expect(await AccountStorage.isCoachMembershipActive(), isFalse);
  });

  test('accepts a current StoreKit expiration', () async {
    await AccountStorage.setCoachMembershipActive(
      true,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );

    expect(await AccountStorage.isCoachMembershipActive(), isTrue);
  });

  test('rejects an expired StoreKit expiration', () async {
    await AccountStorage.setCoachMembershipActive(
      true,
      expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );

    expect(await AccountStorage.isCoachMembershipActive(), isFalse);
  });

  test('invalidates membership grants written by older builds', () async {
    SharedPreferences.setMockInitialValues({
      'user_id': userId,
      'coach_membership_active_u$userId': true,
      'coach_membership_verified_at_u$userId':
          DateTime.now().millisecondsSinceEpoch,
      'coach_membership_verification_version_u$userId': 2,
    });

    expect(await AccountStorage.isCoachMembershipActive(), isFalse);
  });
}
