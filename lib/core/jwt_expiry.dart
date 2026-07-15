import 'dart:convert';

bool accessTokenExpiresSoon(
  String token, {
  DateTime? now,
  Duration refreshBefore = const Duration(seconds: 60),
}) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return true;
    final rawExp = payload['exp'];
    final exp = rawExp is int ? rawExp : int.tryParse(rawExp.toString());
    if (exp == null) return true;
    final current = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    return exp <= current + refreshBefore.inSeconds;
  } catch (_) {
    return true;
  }
}
