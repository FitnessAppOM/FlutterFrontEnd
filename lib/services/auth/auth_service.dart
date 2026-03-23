import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../config/base_url.dart';
import '../../core/account_storage.dart';

Future<Map<String, dynamic>?> signInWithGoogle() async {
  try {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final userCredential =
    await FirebaseAuth.instance.signInWithCredential(credential);

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) return null;

    final firebaseIdToken = await firebaseUser.getIdToken();

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/auth/google"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "token": firebaseIdToken,
      }),
    );

    if (response.statusCode != 200) {
      await AccountStorage.handleAuthStatus(
        response.statusCode,
        responseBody: response.body,
      );
      throw Exception("Backend Google login failed");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e) {
    print("Google Sign-In error: $e");
    return null;
  }
}

String _generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List<String>.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

void _debugApple(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

Map<String, dynamic>? _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
  } catch (_) {
    return null;
  }
  return null;
}

Future<Map<String, dynamic>?> signInWithApple() async {
  try {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);
    final pkg = await PackageInfo.fromPlatform();
    final expectedAud = pkg.packageName;
    _debugApple("Apple nonce: rawLen=${rawNonce.length} hashPrefix=${nonce.substring(0, 8)}");

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    _debugApple(
      "Apple credential: identityToken=${appleCredential.identityToken != null} "
      "authorizationCode=${appleCredential.authorizationCode.isNotEmpty} "
      "email=${appleCredential.email != null} "
      "nameProvided=${(appleCredential.givenName ?? '').isNotEmpty || (appleCredential.familyName ?? '').isNotEmpty}",
    );

    if (appleCredential.identityToken == null) {
      _debugApple("Apple sign-in aborted: identityToken is null");
      return null;
    }

    final payload = _decodeJwtPayload(appleCredential.identityToken!);
    if (payload != null) {
      final aud = payload['aud'];
      final audText = aud is List ? aud.join(',') : aud?.toString();
      _debugApple(
        "Apple JWT: aud=$audText iss=${payload['iss']} nonce=${payload['nonce']} "
        "exp=${payload['exp']} iat=${payload['iat']} sub=${payload['sub']}",
      );
      _debugApple("Expected aud(bundleId)=$expectedAud nonceHashPrefix=${nonce.substring(0, 8)}");
    } else {
      _debugApple("Apple JWT: failed to decode payload");
    }

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      // Some Firebase backends expect the auth code as accessToken for Apple.
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) return null;

    final firebaseIdToken = await firebaseUser.getIdToken();

    final fullName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].where((p) => p != null && p!.trim().isNotEmpty).map((p) => p!.trim()).join(' ');

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/auth/apple"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "token": firebaseIdToken,
        if (fullName.isNotEmpty) "name": fullName,
      }),
    );

    if (response.statusCode != 200) {
      await AccountStorage.handleAuthStatus(
        response.statusCode,
        responseBody: response.body,
      );
      throw Exception("Backend Apple login failed");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e) {
    print("Apple Sign-In error: $e");
    return null;
  }
}
