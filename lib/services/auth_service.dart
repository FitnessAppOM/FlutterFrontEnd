import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/base_url.dart';
// Android client ID is not needed anymore
// const _androidClientId = "...";

const _iosClientId =
    "547065160142-mr1pjpoho6d1ql1ti0jttsa6r1b7t5dk.apps.googleusercontent.com";

//  Your backend’s WEB CLIENT ID (serverClientId)
const _webClientId =
    "547065160142-m809lbb6qc4s7u6eohqbf77b32nld9q4.apps.googleusercontent.com";

Future<String?> signInWithGoogle() async {
  try {
    final signIn = GoogleSignIn.instance;

    // ----------------------------------------------------------
    // IMPORTANT: Only pass serverClientId.
    // Do NOT pass Android clientId → It breaks on your friend’s device.
    // ----------------------------------------------------------
    if (Platform.isIOS) {
      await signIn.initialize(
        clientId: _iosClientId,     // only for iOS
        serverClientId: _webClientId,
      );
    } else {
      await signIn.initialize(
        serverClientId: _webClientId, // Android/Web
      );
    }

    await signIn.attemptLightweightAuthentication();
    final account = await signIn.authenticate();

    final auth = account.authentication;
    final idToken = auth.idToken;

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/auth/google"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": idToken}),
    );

    return response.body;
  } catch (e) {
    print("Google Sign-In error: $e");
    return null;
  }
}
