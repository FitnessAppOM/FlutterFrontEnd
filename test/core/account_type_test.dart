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
  });
}
