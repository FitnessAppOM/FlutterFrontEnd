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

  test('queues and completes the post-purchase intro per account', () async {
    await AccountStorage.schedulePostPurchaseIntro();
    expect(await AccountStorage.shouldShowPostPurchaseIntro(), isTrue);

    await AccountStorage.completePostPurchaseIntro();
    expect(await AccountStorage.shouldShowPostPurchaseIntro(), isFalse);

    await AccountStorage.schedulePostPurchaseIntro();
    expect(await AccountStorage.shouldShowPostPurchaseIntro(), isFalse);
  });

  test('does not leak a pending intro to another account', () async {
    await AccountStorage.schedulePostPurchaseIntro();

    SharedPreferences.setMockInitialValues({'user_id': userId + 1});
    expect(await AccountStorage.shouldShowPostPurchaseIntro(), isFalse);
  });

  test('tracks each post-purchase module independently', () async {
    await AccountStorage.schedulePostPurchaseIntro();

    expect(
      await AccountStorage.shouldShowPostPurchaseIntroModule('dashboard'),
      isTrue,
    );
    expect(
      await AccountStorage.shouldShowPostPurchaseIntroModule('diet'),
      isTrue,
    );

    await AccountStorage.completePostPurchaseIntroModule('dashboard');

    expect(
      await AccountStorage.shouldShowPostPurchaseIntroModule('dashboard'),
      isFalse,
    );
    expect(
      await AccountStorage.shouldShowPostPurchaseIntroModule('diet'),
      isTrue,
    );
    expect(await AccountStorage.shouldShowPostPurchaseIntro(), isTrue);
  });

  test('finishes the account-wide intro after all five modules', () async {
    await AccountStorage.schedulePostPurchaseIntro();

    for (final module in const [
      'dashboard',
      'diet',
      'training',
      'community',
      'coach',
    ]) {
      await AccountStorage.completePostPurchaseIntroModule(module);
    }

    expect(await AccountStorage.shouldShowPostPurchaseIntro(), isFalse);
    expect(
      await AccountStorage.shouldShowPostPurchaseIntroModule('coach'),
      isFalse,
    );
  });
}
