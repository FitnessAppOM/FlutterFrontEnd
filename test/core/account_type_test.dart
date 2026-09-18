import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/core/account_type.dart';

void main() {
  group('AccountType.isCoach', () {
    test('uses the persisted signup choice before approval', () {
      expect(
        AccountType.isCoach({
          'account_type': 'coach',
          'is_expert': false,
          'filled_expert_questionnaire': false,
        }),
        isTrue,
      );
    });

    test('keeps approved and submitted legacy coaches compatible', () {
      expect(AccountType.isCoach({'is_expert': true}), isTrue);
      expect(
        AccountType.isCoach({'filled_expert_questionnaire': true}),
        isTrue,
      );
    });

    test('defaults missing and client accounts to client', () {
      expect(AccountType.isCoach(null), isFalse);
      expect(AccountType.isCoach({'account_type': 'client'}), isFalse);
    });

    test('developer role can open the coach portal from either account mode', () {
      expect(
        AccountType.isCoach({
          'account_type': 'client',
          'is_expert': false,
          'is_developer': true,
        }),
        isTrue,
      );
    });
  });

  group('AccountType.isApprovedCoach', () {
    test('accepts an approved expert despite a missing questionnaire flag', () {
      expect(
        AccountType.isApprovedCoach({
          'account_type': 'coach',
          'is_expert': true,
          'expert_profile_status': 'Approved',
          'filled_expert_questionnaire': false,
        }),
        isTrue,
      );
    });

    test('does not bypass onboarding for pending or non-expert accounts', () {
      expect(
        AccountType.isApprovedCoach({
          'is_expert': true,
          'expert_profile_status': 'pending',
        }),
        isFalse,
      );
      expect(
        AccountType.isApprovedCoach({
          'is_expert': false,
          'expert_profile_status': 'approved',
        }),
        isFalse,
      );
    });

    test('developer role bypasses coach approval routing', () {
      expect(
        AccountType.isApprovedCoach({
          'is_developer': true,
          'is_expert': false,
          'expert_profile_status': 'suspended',
        }),
        isTrue,
      );
    });
  });

  group('AccountType.canUseCoachTools', () {
    test('allows administrators without a paid coach membership', () {
      expect(
        AccountType.canUseCoachTools(
          hasActiveCoachMembership: false,
          isDeveloper: false,
          isAdmin: true,
        ),
        isTrue,
      );
    });

    test('keeps the normal membership and developer paths', () {
      expect(
        AccountType.canUseCoachTools(
          hasActiveCoachMembership: true,
          isDeveloper: false,
          isAdmin: false,
        ),
        isTrue,
      );
      expect(
        AccountType.canUseCoachTools(
          hasActiveCoachMembership: false,
          isDeveloper: true,
          isAdmin: false,
        ),
        isTrue,
      );
    });

    test('rejects users with no coach access source', () {
      expect(
        AccountType.canUseCoachTools(
          hasActiveCoachMembership: false,
          isDeveloper: false,
          isAdmin: false,
        ),
        isFalse,
      );
    });
  });
}
