import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/core/jwt_expiry.dart';

String _tokenWithExpiry(int epochSeconds) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'})));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'sub': '42', 'exp': epochSeconds})),
  );
  return '$header.$payload.signature';
}

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

  test('access token outside refresh window stays usable', () {
    expect(
      accessTokenExpiresSoon(_tokenWithExpiry(nowSeconds + 600), now: now),
      isFalse,
    );
  });

  test('access token inside refresh window rotates proactively', () {
    expect(
      accessTokenExpiresSoon(_tokenWithExpiry(nowSeconds + 30), now: now),
      isTrue,
    );
  });

  test('malformed token fails closed', () {
    expect(accessTokenExpiresSoon('not-a-jwt', now: now), isTrue);
  });
}
