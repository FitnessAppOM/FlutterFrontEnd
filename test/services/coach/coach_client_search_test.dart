import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/coach/coach_client_search.dart';

void main() {
  const fields = <String?>[
    'John Michael Doe',
    'John',
    'Doe',
    'john_doe',
    'john.doe@university.edu',
    '152',
  ];

  test('matches names in any term order', () {
    expect(matchesCoachClientSearch(query: 'doe john', fields: fields), isTrue);
  });

  test('matches username with or without common separators', () {
    expect(
      matchesCoachClientSearch(query: '@john_doe', fields: fields),
      isTrue,
    );
    expect(matchesCoachClientSearch(query: 'johndoe', fields: fields), isTrue);
  });

  test('matches partial email and user id', () {
    expect(
      matchesCoachClientSearch(query: 'john university', fields: fields),
      isTrue,
    );
    expect(matchesCoachClientSearch(query: '152', fields: fields), isTrue);
  });

  test('empty query shows every client and unknown query does not match', () {
    expect(matchesCoachClientSearch(query: '  ', fields: fields), isTrue);
    expect(
      matchesCoachClientSearch(query: 'someone else', fields: fields),
      isFalse,
    );
  });
}
