import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/coach/coach_client_search.dart';

void main() {
  const identityFields = <String?>[
    'John Michael Doe',
    'John',
    'Doe',
    'john_doe',
  ];
  const email = 'john.doe@university.edu';
  const userId = '152';

  test('matches names in any term order', () {
    expect(
      matchesCoachClientSearch(
        query: 'doe john',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isTrue,
    );
  });

  test('matches username with or without common separators', () {
    expect(
      matchesCoachClientSearch(
        query: '@john_doe',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isTrue,
    );
    expect(
      matchesCoachClientSearch(
        query: 'johndoe',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isTrue,
    );
  });

  test('matches an email-shaped query and exact user id', () {
    expect(
      matchesCoachClientSearch(
        query: 'john.doe@university',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isTrue,
    );
    expect(
      matchesCoachClientSearch(
        query: '152',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isTrue,
    );
    expect(
      matchesCoachClientSearch(
        query: '15',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isFalse,
    );
  });

  test('does not match a generic email domain', () {
    expect(
      matchesCoachClientSearch(
        query: 'university',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isFalse,
    );
  });

  test('empty query shows every client and unknown query does not match', () {
    expect(
      matchesCoachClientSearch(
        query: '  ',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isTrue,
    );
    expect(
      matchesCoachClientSearch(
        query: 'someone else',
        identityFields: identityFields,
        email: email,
        userId: userId,
      ),
      isFalse,
    );
  });
}
