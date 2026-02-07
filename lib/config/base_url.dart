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
    // iOS (REAL DEVICE)git st
    // ---------------------------
    if (Platform.isIOS) {
      // Update this to your Mac's current LAN IP when testing on a real device.
      const macLocalIP = "172.20.10.3";
      return "http://$macLocalIP:8000";
    }

    // ---------------------------
    // FALLBACK (Desktop / Web)
    // ---------------------------
    return "http://localhost:8000";
  }
}
