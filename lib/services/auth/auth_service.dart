import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';

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
      throw Exception("Backend Google login failed");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (e) {
    print("Google Sign-In error: $e");
    return null;
  }
}
