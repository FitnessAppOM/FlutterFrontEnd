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
    // IOS SIMULATOR / REAL IPHONE
    // ---------------------------
    if (Platform.isIOS) {
      // CHANGE THIS EVERY TIME YOUR MAC IP CHANGES
      const macLocalIP = "127.0.0.1";
      return "http://$macLocalIP:8000";
    }

    // ---------------------------
    // macOS or Windows Desktop apps
    // ---------------------------
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return "http://localhost:8000";
    }

    // Web fallback (if ever needed)
    return "http://localhost:8000";
  }
}