import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    // ---------------------------
    // ANDROID EMULATOR
    // ---------------------------
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8000";
    }

    // ---------------------------
    // iOS (REAL DEVICE)
    // ---------------------------
    if (Platform.isIOS) {
      const macLocalIP = "10.245.224.125";
      return "http://$macLocalIP:8000";
    }

    // ---------------------------
    // FALLBACK (Desktop / Web)
    // ---------------------------
    return "http://localhost:8000";
  }
}