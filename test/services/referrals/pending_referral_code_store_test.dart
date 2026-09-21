import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/services/referrals/pending_referral_code_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PendingReferralCodeStore.clear();
  });

  test('stores and reloads a valid referral code', () async {
    await PendingReferralCodeStore.remember('tq1234567890abcdef');

    expect(PendingReferralCodeStore.code.value, 'TQ1234567890ABCDEF');
    expect(await PendingReferralCodeStore.load(), 'TQ1234567890ABCDEF');
  });

  test('ignores invalid referral codes', () async {
    await PendingReferralCodeStore.remember('invalid');
    expect(PendingReferralCodeStore.code.value, isNull);
    expect(await PendingReferralCodeStore.load(), isNull);
  });

  test('clears a pending referral code', () async {
    await PendingReferralCodeStore.remember('TQ1234567890ABCDEF');
    await PendingReferralCodeStore.clear();

    expect(PendingReferralCodeStore.code.value, isNull);
    expect(await PendingReferralCodeStore.load(), isNull);
  });
}
